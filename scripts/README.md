<!-- CONFIDENTIAL-CHECK-EXEMPT — this file documents the check and must contain the marker words. -->

# Scripts

| Script | What it does |
|---|---|
| `build-all.sh` | Builds the whole polyrepo in dependency order and installs shared artifacts to `~/.m2`. Uses `clean package` — plain `package` treats a module as up to date when only a *dependency* changed, so a rebuilt commons jar silently never reaches the service fat jar. |
| `e2e-agent-flow.sh` | Cross-service machine-to-machine checks through the real gateway against a running stack. |
| `e2e-interactive-login.sh` | The browser-facing leg: `authorization_code` + PKCE including form login, CSRF and session cookies. |
| `check-confidential.sh` | Refuses to let a file marked confidential live in a repository that is, or can become, public. |
| `install-hooks.sh` | Installs `check-confidential.sh` as a `pre-commit` hook in every sibling repo. |

## Why `check-confidential.sh` exists

The patent disclosure and its companion carried a `CONFIDENTIAL — do not publish before filing`
header and were committed to a **public** repository anyway. They were world-readable from
**2026-08-18**.

A marking in a file's text is a note to humans. It stops nothing. Under 35 U.S.C. §102(b)(1) that
starts a 12-month US clock, and in absolute-novelty jurisdictions (EPO, China, most others) a
pre-filing public disclosure is prior art against the applicant's own later application. The cost of
the mistake is forfeited rights; the cost of the check is a second per commit.

**Marking a file:** put `AEGIS-CONFIDENTIAL` anywhere in it. Legacy human phrasings
(`CONFIDENTIAL`, `DO NOT PUBLISH`) are honoured too, but only in the first 8 lines — a document that
*describes* a confidential file is not itself confidential, and a check that cries wolf on the index
page is a check people switch off.

**Acknowledging a known exposure:** list the path in the repo's `.confidential-allow`, with the
reason. It is then reported but does not fail the build, so the gate keeps failing on anything *new*
instead of being disabled wholesale.

```bash
scripts/check-confidential.sh          # every sibling repo
scripts/check-confidential.sh ../foo   # one repo
scripts/install-hooks.sh               # install as pre-commit everywhere
```
