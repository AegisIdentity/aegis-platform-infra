#!/usr/bin/env bash
# CONFIDENTIAL-CHECK-EXEMPT — this file implements the check and must contain the marker words.
# Install the confidential-material check as a pre-commit hook in every sibling repo.
#
# The check is cheap and the failure it prevents is not: a file marked confidential, committed to a
# repository that is or can become public, is a disclosure — and a disclosure cannot be taken back.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHECK="$ROOT/aegis-platform-infra/scripts/check-confidential.sh"

for repo in "$ROOT"/*/; do
  repo="${repo%/}"
  [ -d "$repo/.git" ] || continue
  hook="$repo/.git/hooks/pre-commit"

  cat > "$hook" <<HOOK
#!/usr/bin/env bash
# Installed by aegis-platform-infra/scripts/install-hooks.sh
exec "$CHECK" "$repo"
HOOK
  chmod +x "$hook"
  echo "  installed pre-commit hook: $(basename "$repo")"
done

echo
echo "Done. Bypass in a genuine emergency with 'git commit --no-verify' — and then go and fix it."
