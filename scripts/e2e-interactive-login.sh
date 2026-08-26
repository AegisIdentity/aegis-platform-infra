#!/usr/bin/env bash
# Interactive authorization_code + PKCE login, end to end through the edge gateway.
#
# WHY NOT A HEADLESS BROWSER
# --------------------------
# The sign-in page is server-rendered Thymeleaf with no client-side JavaScript in the auth path, so
# a cookie jar reproduces exactly what a browser does: follow the redirect, read the CSRF token out
# of the form, POST credentials, follow back, exchange the code. Adding Playwright would add a large
# dependency and test the same HTTP exchanges less directly.
#
# WHAT THIS COVERS THAT NOTHING ELSE DOES
# ---------------------------------------
# The browser-facing leg: session cookie handling, CSRF, the login POST, the authorization redirect,
# PKCE verification, and the fact that the issuer a browser sees through the gateway is the one the
# resulting token actually carries. Every other check in this suite is machine-to-machine.
set -uo pipefail

GATEWAY="${GATEWAY:-http://localhost:8080}"
USERNAME="${AEGIS_DEV_USER:-dev-user}"
PASSWORD="${AEGIS_DEV_PASSWORD:-dev-only-change-me}"
TENANT="${AEGIS_DEV_TENANT:-dev}"
CLIENT_ID="${SPA_CLIENT_ID:-aegis-dev-spa}"
REDIRECT_URI="${SPA_REDIRECT_URI:-http://localhost:3000/callback}"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; }

JAR=$(mktemp)
trap 'rm -f "$JAR" "$JAR".hdr' EXIT

# --- PKCE ---------------------------------------------------------------------------------------
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
VERIFIER=$(openssl rand -hex 32)
CHALLENGE=$(printf '%s' "$VERIFIER" | openssl dgst -binary -sha256 | b64url)

printf '\n\033[1mInteractive authorization_code + PKCE through the gateway\033[0m\n'

# --- 1. start the flow; expect a redirect to the login page --------------------------------------
# Start at the PER-TENANT issuer (/{tenant}/oauth2/authorize), not the root one. dev-user lives in
# tenant "dev"; the root issuer resolves to the "default" tenant and the credentials would correctly
# be rejected there. This is the split-horizon issuer model working as designed, not a workaround.
AUTH_URL="$GATEWAY/$TENANT/oauth2/authorize?response_type=code&client_id=$CLIENT_ID&scope=openid%20profile&redirect_uri=$REDIRECT_URI&code_challenge=$CHALLENGE&code_challenge_method=S256"
LOGIN_LOC=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w '%{redirect_url}' "$AUTH_URL")
case "$LOGIN_LOC" in
  *"/login"*) ok "unauthenticated authorize redirects to the sign-in page" ;;
  *) bad "authorize did not redirect to login" "got: ${LOGIN_LOC:-<none>}"; ;;
esac

# --- 2. fetch the login form and read its CSRF token ---------------------------------------------
LOGIN_HTML=$(curl -s -c "$JAR" -b "$JAR" "$GATEWAY/login")
CSRF=$(printf '%s' "$LOGIN_HTML" | sed -n 's/.*name="_csrf"[^>]*value="\([^"]*\)".*/\1/p' | head -1)
if [ -n "$CSRF" ]; then ok "sign-in page served with a CSRF token"; else bad "no CSRF token in the login form"; fi

# --- 3. post credentials --------------------------------------------------------------------------
LOGIN_REDIRECT=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w '%{redirect_url}' \
  -d "username=$USERNAME" -d "password=$PASSWORD" -d "tenant=$TENANT" -d "_csrf=$CSRF" \
  "$GATEWAY/login")
case "$LOGIN_REDIRECT" in
  *"/login?error"*) bad "credentials rejected" \
      "if the AS signing key changed recently, restart identity-service so it refetches the AS JWKS" ;;
  "") bad "login produced no redirect" ;;
  *) ok "credentials accepted (redirected to $(printf '%s' "$LOGIN_REDIRECT" | cut -c1-48)...)" ;;
esac

# --- 4. resume authorize; expect the code at the redirect_uri -------------------------------------
CODE_LOC=$(curl -s -c "$JAR" -b "$JAR" -o /dev/null -w '%{redirect_url}' "$AUTH_URL")
CODE=$(printf '%s' "$CODE_LOC" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
if [ -n "$CODE" ]; then ok "authorization code issued to the registered redirect_uri"; \
  else bad "no authorization code" "redirect was: ${CODE_LOC:-<none>}"; fi

# --- 5. exchange the code, with the PKCE verifier -------------------------------------------------
if [ -n "$CODE" ]; then
  TOKENS=$(curl -s -d grant_type=authorization_code -d "code=$CODE" \
    -d "redirect_uri=$REDIRECT_URI" -d "client_id=$CLIENT_ID" -d "code_verifier=$VERIFIER" \
    "$GATEWAY/oauth2/token")
  ACCESS=$(printf '%s' "$TOKENS" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
  ID_TOKEN=$(printf '%s' "$TOKENS" | sed -n 's/.*"id_token":"\([^"]*\)".*/\1/p')

  if [ -n "$ACCESS" ]; then ok "code exchanged for an access token"; else bad "code exchange failed" "$(printf '%s' "$TOKENS" | head -c 200)"; fi
  if [ -n "$ID_TOKEN" ]; then ok "an OIDC id_token was issued"; else bad "no id_token — openid scope not honoured"; fi

  decode() { B=$(printf '%s' "$1" | cut -d. -f2 | tr '_-' '/+'); case $(( ${#B} % 4 )) in 2) B="${B}==";; 3) B="${B}=";; esac; printf '%s' "$B" | base64 -d 2>/dev/null; }
  PAYLOAD=$(decode "$ACCESS")
  HEADER=$(B=$(printf '%s' "$ACCESS" | cut -d. -f1 | tr '_-' '/+'); case $(( ${#B} % 4 )) in 2) B="${B}==";; 3) B="${B}=";; esac; printf '%s' "$B" | base64 -d 2>/dev/null)

  # The browser reached the gateway, so the issuer in the token must be the gateway — not the
  # in-network AS host. That is the split-horizon property, and it only exists across a real hop.
  case "$PAYLOAD" in
    *'"iss":"http://localhost:8080'*) ok "token issuer is the GATEWAY, as the browser saw it" ;;
    *) bad "issuer is not the gateway" "$(printf '%s' "$PAYLOAD" | head -c 160)" ;;
  esac

  case "$PAYLOAD" in
    *'"sub":"'"$USERNAME"'"'*) ok "token subject is the logged-in user, not the client" ;;
    *) bad "subject is not the logged-in user" "$(printf '%s' "$PAYLOAD" | head -c 180)" ;;
  esac

  # uid is stamped from the authenticated principal, so it can only be present after a real login.
  case "$PAYLOAD" in
    *'"uid":'*) ok "token carries the resolved user id from the directory" ;;
    *) bad "uid claim missing — the principal did not come from identity-service" ;;
  esac

  # Vault-backed signing (ADR-0015) produces a kid carrying the KEY VERSION; the legacy local store
  # produced a random suffix. This distinguishes them without trusting configuration.
  case "$HEADER" in
    *'"kid":"aegis-'*'-v'*) ok "signed by a Vault Transit key (kid carries the key version)" ;;
    *) bad "not signed by Vault" "$HEADER" ;;
  esac

  # A browser-obtained token must work against a protected endpoint, through the gateway. Called at
  # the SAME per-tenant issuer the token was minted under — /userinfo at the root issuer is a
  # different issuer, and rejecting a foreign-issuer token there is correct behaviour, not a bug.
  ME=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $ACCESS" "$GATEWAY/$TENANT/userinfo")
  if [ "$ME" = "200" ]; then ok "the browser's token is accepted at the tenant's /userinfo"; \
    else bad "/userinfo rejected the token" "HTTP $ME"; fi
fi

printf '\n\033[1m─────────────────────────────────────────\033[0m\n'
printf '  passed: \033[32m%s\033[0m   failed: \033[31m%s\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
