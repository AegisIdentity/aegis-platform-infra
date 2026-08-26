#!/usr/bin/env bash
# CONFIDENTIAL-CHECK-EXEMPT — this file implements the check and must contain the marker words.
# Refuse to let a file marked confidential sit in a repository that is (or can become) public.
#
# WHY THIS EXISTS
# ---------------
# The patent disclosure and its companion were written with a "CONFIDENTIAL — do not publish before
# filing" header, in good faith, and then committed to a PUBLIC GitHub repository. They were
# world-readable from 2026-08-18. A marking in a file's text is a note to humans; it stops nothing.
#
# Under 35 U.S.C. §102(b)(1) that starts a 12-month US clock, and in absolute-novelty jurisdictions
# (EPO, China, most others) a pre-filing public disclosure is prior art against the applicant's own
# later application. The cost of the mistake is measured in forfeited rights, so the check is cheap
# by comparison.
#
#   usage:  scripts/check-confidential.sh [repo-dir ...]     # defaults to every sibling repo
#   hook:   ln -s ../../aegis-platform-infra/scripts/check-confidential.sh .git/hooks/pre-commit
#   CI:     run it as a required job
set -uo pipefail

# The explicit, machine-readable marker. Put it in any file that must never be public; the literal
# form is AEGIS- followed immediately by CONFIDENTIAL.
#
# Assembled at runtime rather than written literally, because the very first thing this check did on
# being wired in as a pre-commit hook was block its OWN commit: the script necessarily contains the
# marker strings, so it matched itself. That is precisely the cry-wolf failure this check is supposed
# to avoid, so it is fixed here rather than papered over with a path exclusion.
EXPLICIT_MARKER='AEGIS-'"CONFIDENTIAL"

# Legacy human markings. Only honoured in a file HEADER, because a document that *describes* a
# confidential file ("see the disclosure, do not publish before filing") is not itself confidential —
# and a check that cries wolf on the index page is a check people switch off.
HEADER_MARKERS='CONFIDENTIAL|DO NOT PUBLISH|do not publish before filing'
HEADER_LINES=8

# A file that documents or implements this mechanism has to contain the marker words, and is not
# itself secret. It opts out with this token (literal form: CONFIDENTIAL-CHECK followed by -EXEMPT).
EXEMPT_TOKEN='CONFIDENTIAL-CHECK'"-EXEMPT"

FAIL=0
red()  { printf '\033[31m%s\033[0m\n' "$1"; }
grn()  { printf '\033[32m%s\033[0m\n' "$1"; }
warn() { printf '\033[33m%s\033[0m\n' "$1"; }

check_repo() {
  local repo="$1"
  [ -d "$repo/.git" ] || return 0

  local name; name=$(basename "$repo")

  # Visibility, when gh is available and authenticated. Unknown visibility is treated as PUBLIC:
  # failing safe matters more here than avoiding a false alarm, because the mistake is irreversible.
  local visibility="UNKNOWN"
  if command -v gh >/dev/null 2>&1; then
    local remote; remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
    if [ -n "$remote" ]; then
      # Portable slug extraction: BSD sed has no non-greedy repetition, so do it with shell
      # parameter expansion instead of a regex that only works on GNU.
      # Strip the SCHEME first. Doing "${remote##*:}" up front looks tempting and is wrong: it
      # strips through the colon in "https:", leaving "//github.com/owner/repo".
      local slug="${remote%.git}"
      slug="${slug#https://}"
      slug="${slug#http://}"
      slug="${slug#ssh://}"
      slug="${slug#git@}"
      slug="${slug/:/\/}"                               # git@host:owner/repo -> host/owner/repo
      case "$slug" in */*/*) slug="${slug#*/}" ;; esac   # host/owner/repo    -> owner/repo
      visibility=$(gh repo view "$slug" --json visibility -q .visibility 2>/dev/null || echo "UNKNOWN")
    else
      visibility="NO_REMOTE"
    fi
  fi

  # Already-acknowledged exposures. A file listed in .confidential-allow is reported but does not
  # fail the check — so a KNOWN, decided situation can be recorded explicitly instead of someone
  # switching the whole check off, which is what usually happens to a permanently-red gate.
  local allow="$repo/.confidential-allow"

  # Only TRACKED files matter: an untracked file has not been published by us.
  local hits=""
  local acked=""
  while IFS= read -r f; do
    [ -f "$repo/$f" ] || continue
    case "$f" in *.png|*.jpg|*.pdf|*.jar|*.zip|*.drawio) continue ;; esac
    # Explicit opt-out for the tooling and its documentation.
    if grep -q "$EXEMPT_TOKEN" "$repo/$f" 2>/dev/null; then
      continue
    fi

    if grep -q "$EXPLICIT_MARKER" "$repo/$f" 2>/dev/null \
       || head -"$HEADER_LINES" "$repo/$f" 2>/dev/null | grep -qiE "$HEADER_MARKERS"; then
      if [ -f "$allow" ] && grep -qxF "$f" "$allow" 2>/dev/null; then
        acked="$acked$f"$'\n'
      else
        hits="$hits$f"$'\n'
      fi
    fi
  done < <(git -C "$repo" ls-files 2>/dev/null)

  if [ -n "$acked" ]; then
    warn "  $name [$visibility] — acknowledged exposure (see .confidential-allow):"
    printf '%s' "$acked" | sed 's/^/      /'
  fi

  if [ -z "$hits" ]; then
    return 0
  fi

  case "$visibility" in
    PRIVATE)
      warn "  $name [PRIVATE] — confidential files present, repo is private:"
      printf '%s' "$hits" | sed 's/^/      /'
      ;;
    NO_REMOTE)
      warn "  $name [no remote] — confidential files present, not yet pushed anywhere:"
      printf '%s' "$hits" | sed 's/^/      /'
      ;;
    *)
      red "  $name [$visibility] — CONFIDENTIAL FILES IN A PUBLIC (or unverified) REPO:"
      printf '%s' "$hits" | sed 's/^/      /'
      FAIL=1
      ;;
  esac
}

printf '\n\033[1mConfidential-material check\033[0m\n'

if [ $# -gt 0 ]; then
  for r in "$@"; do check_repo "$(cd "$r" && pwd)"; done
else
  ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
  for r in "$ROOT"/*/; do check_repo "${r%/}"; done
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  grn "  OK — no confidential-marked file is tracked in a public repository."
else
  red "  FAILED — see above."
  cat <<'ADVICE'

  A marking in the file text stops nothing. Either:
    - move the file outside every repository (this workspace root is not a repo), or
    - make the repository private, or
    - remove the marking if the content is genuinely not confidential.

  Note: for material ALREADY pushed, deleting the file does not undo the disclosure and may
  complicate the evidentiary record. Take advice before rewriting history.
ADVICE
fi
exit "$FAIL"
