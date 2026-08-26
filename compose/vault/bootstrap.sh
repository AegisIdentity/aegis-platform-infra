#!/bin/sh
# Aegis local Vault bootstrap — initialize, unseal, enable engines, seed per-tenant policies.
#
# DEV ONLY. This writes unseal keys and a root token to a shared volume so `docker compose up` is a
# single command. No deployed environment does this: there Vault auto-unseals via cloud KMS and the
# root token is revoked immediately after bootstrap.
#
# `set -e` matters here. An earlier version swallowed every error with `|| true`, so a failed unseal
# looked like success and the first real symptom was a 503 "Vault is sealed" several steps later.
set -eu

VAULT_ADDR_0="http://vault-0:8200"
KEYS_FILE=/vault/bootstrap/init.json
export VAULT_ADDR="$VAULT_ADDR_0"

echo "[bootstrap] waiting for vault-0 ..."
i=0
while [ $i -lt 60 ]; do
  vault status >/dev/null 2>&1 && break
  # exit code 2 = up but sealed/uninitialized, which is exactly what we are waiting to see
  [ $? -eq 2 ] && break
  i=$((i + 1))
  sleep 2
done

if vault status 2>/dev/null | grep -q "Initialized.*true"; then
  echo "[bootstrap] already initialized"
else
  echo "[bootstrap] initializing (1 share, threshold 1 — dev only)"
  vault operator init -key-shares=1 -key-threshold=1 -format=json > "$KEYS_FILE"
fi

# The image has no jq, and `vault operator init -format=json` pretty-prints, so the key sits on the
# line AFTER its label. A single-line sed silently produces an empty key — which then "unseals"
# nothing and fails much later with a confusing 503.
UNSEAL_KEY=$(awk '/"unseal_keys_b64"/ {getline; gsub(/[",[:space:]]/, ""); print; exit}' "$KEYS_FILE")
ROOT_TOKEN=$(awk -F'"' '/"root_token"/ {print $4; exit}' "$KEYS_FILE")

if [ -z "$UNSEAL_KEY" ] || [ -z "$ROOT_TOKEN" ]; then
  echo "[bootstrap] FATAL: could not parse unseal key or root token from $KEYS_FILE" >&2
  exit 1
fi

for node in vault-0 vault-1 vault-2; do
  echo "[bootstrap] unsealing $node"
  # Followers may still be joining the raft cluster; retry rather than give up.
  j=0
  while [ $j -lt 15 ]; do
    if VAULT_ADDR="http://$node:8200" vault operator unseal "$UNSEAL_KEY" >/dev/null 2>&1; then
      break
    fi
    j=$((j + 1))
    sleep 2
  done
done

export VAULT_ADDR="$VAULT_ADDR_0"
export VAULT_TOKEN="$ROOT_TOKEN"

# Verify rather than assume. This is the check whose absence hid the original failure.
if vault status | grep -q "Sealed.*true"; then
  echo "[bootstrap] FATAL: vault-0 is still sealed after unseal" >&2
  vault status || true
  exit 1
fi
echo "[bootstrap] vault-0 is unsealed"

echo "[bootstrap] enabling engines under the aegis/ mount"
vault secrets enable -path=aegis/transit transit  2>/dev/null || echo "  transit already enabled"
vault secrets enable -path=aegis/kv -version=2 kv 2>/dev/null || echo "  kv already enabled"
vault secrets enable -path=aegis/pki pki          2>/dev/null || echo "  pki already enabled"

# Per-tenant keys and policies for the seeded demo tenants.
#
# One shared mount per engine. Transit key names cannot contain "/", so the tenant is a NAME PREFIX;
# a mount per tenant would cap tenant count at Vault's ~14k mount limit and slow leadership transfer.
# KV does support nesting, so there the tenant is a path segment.
for tenant in default dev acme globex; do
  echo "[bootstrap] provisioning tenant $tenant"

  # exportable=false is not negotiable: an exportable key defeats the reason for using transit.
  vault write -f "aegis/transit/keys/${tenant}-token-signing" \
      type=rsa-2048 exportable=false allow_plaintext_backup=false >/dev/null

  vault policy write "aegis-tenant-${tenant}" - >/dev/null <<POLICY
path "aegis/transit/keys/${tenant}-tenant-managed-*"   { capabilities = ["create","read","update","list"] }
path "aegis/transit/sign/${tenant}-tenant-managed-*"   { capabilities = ["update"] }
path "aegis/transit/verify/${tenant}-tenant-managed-*" { capabilities = ["update"] }
path "aegis/kv/data/${tenant}/*"                       { capabilities = ["create","read","update","delete","list"] }
# A tenant may manage its OWN keys but never the key Aegis uses to sign that tenant's tokens.
# Deny on the key alone is not enough — signing is a separate path.
path "aegis/transit/keys/${tenant}-token-signing"      { capabilities = ["deny"] }
path "aegis/transit/sign/${tenant}-token-signing"      { capabilities = ["deny"] }
POLICY
done

# A SCOPED token for the platform services, written to the shared volume as a file.
#
# Deliberately not the root token: root can destroy the cluster, and a service that only needs to
# create and use keys under aegis/ should not be able to. Deliberately a FILE and not an environment
# variable, because an env var leaks into `docker inspect`, process listings and crash dumps — and
# because a file is the shape Kubernetes and the Vault Agent both use, so dev matches production.
echo "[bootstrap] issuing a scoped platform token"
vault policy write aegis-platform - >/dev/null <<'POLICY'
# Enough to run the platform and the tenant-facing broker; nothing more.
path "aegis/transit/keys/*"   { capabilities = ["create","read","update","list"] }
path "aegis/transit/sign/*"   { capabilities = ["update"] }
path "aegis/transit/verify/*" { capabilities = ["update"] }
path "aegis/kv/data/*"        { capabilities = ["create","read","update","delete","list"] }
path "aegis/kv/metadata/*"    { capabilities = ["read","list","delete"] }
path "aegis/pki/issue/*"      { capabilities = ["update"] }
# Explicitly NOT granted: sys/* (no seal, no policy edits, no mount changes, no revocation of others).
POLICY

vault token create -policy=aegis-platform -period=72h -format=json   | awk -F'"' '/"client_token"/ {print $4; exit}' > /vault/bootstrap/platform-token
chmod 0444 /vault/bootstrap/platform-token
echo "[bootstrap] platform token written to /vault/bootstrap/platform-token"

echo "[bootstrap] raft peers:"
vault operator raft list-peers || true
echo "[bootstrap] done. Root token is in $KEYS_FILE (dev only)."
