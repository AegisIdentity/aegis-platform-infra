#!/bin/sh
# Aegis local Vault bootstrap — initialize, unseal, enable engines, seed per-tenant policies.
#
# DEV ONLY. This writes unseal keys and a root token to a shared volume so `docker compose up` is a
# single command. No deployed environment ever does this: there, Vault auto-unseals via cloud KMS and
# the root token is revoked immediately after bootstrap.
set -eu

VAULT_ADDR_0="http://vault-0:8200"
KEYS_FILE=/vault/bootstrap/init.json
export VAULT_ADDR="$VAULT_ADDR_0"

echo "[bootstrap] waiting for vault-0 ..."
until vault status >/dev/null 2>&1 || [ $? -eq 2 ]; do sleep 2; done

if vault status 2>/dev/null | grep -q "Initialized.*true"; then
  echo "[bootstrap] already initialized"
else
  echo "[bootstrap] initializing (1 share, threshold 1 — dev only)"
  vault operator init -key-shares=1 -key-threshold=1 -format=json > "$KEYS_FILE"
fi

UNSEAL_KEY=$(sed -n 's/.*"unseal_keys_b64": \[[[:space:]]*"\([^"]*\)".*/\1/p' "$KEYS_FILE" | head -1)
ROOT_TOKEN=$(sed -n 's/.*"root_token": "\([^"]*\)".*/\1/p' "$KEYS_FILE" | head -1)

for node in vault-0 vault-1 vault-2; do
  echo "[bootstrap] unsealing $node"
  VAULT_ADDR="http://$node:8200" vault operator unseal "$UNSEAL_KEY" >/dev/null 2>&1 || true
done

export VAULT_ADDR="$VAULT_ADDR_0"
export VAULT_TOKEN="$ROOT_TOKEN"

echo "[bootstrap] enabling engines under the aegis/ mount"
vault secrets enable -path=aegis/transit transit          2>/dev/null || true
vault secrets enable -path=aegis/kv -version=2 kv         2>/dev/null || true
vault secrets enable -path=aegis/pki pki                  2>/dev/null || true

# Per-tenant paths and policies for the seeded demo tenants. PATH isolation is the Vault OSS mode;
# Enterprise uses a namespace per tenant and the application code is identical either way.
for tenant in dev acme globex; do
  echo "[bootstrap] provisioning tenant $tenant"

  # The platform's own signing key for this tenant. exportable=false is not negotiable: an
  # exportable key defeats the entire reason for using transit.
  vault write -f "aegis/transit/keys/${tenant}-token-signing" \
      type=rsa-4096 exportable=false allow_plaintext_backup=false >/dev/null 2>&1 || true

  # A tenant may manage its OWN keys but must never touch the key Aegis uses to sign that tenant's
  # tokens — same namespace, policy-fenced apart.
  vault policy write "aegis-tenant-${tenant}" - <<POLICY >/dev/null
# Transit key names cannot contain "/", so the tenant is a NAME PREFIX inside one shared mount.
# A mount per tenant would cap tenant count at Vault's ~14k mount limit and slow leadership transfer.
path "aegis/transit/keys/${tenant}-tenant-managed-*"   { capabilities = ["create","read","update","list"] }
path "aegis/transit/sign/${tenant}-tenant-managed-*"   { capabilities = ["update"] }
path "aegis/transit/verify/${tenant}-tenant-managed-*" { capabilities = ["update"] }
# KV v2 does support nesting, so there the tenant is a path segment.
path "aegis/kv/data/${tenant}/*"                       { capabilities = ["create","read","update","delete","list"] }
# The tenant may manage its OWN keys but never the key Aegis uses to sign that tenant's tokens.
path "aegis/transit/keys/${tenant}-token-signing"      { capabilities = ["deny"] }
path "aegis/transit/sign/${tenant}-token-signing"      { capabilities = ["deny"] }
POLICY
done

echo "[bootstrap] raft peers:"
vault operator raft list-peers || true
echo "[bootstrap] done. Root token is in $KEYS_FILE (dev only)."
