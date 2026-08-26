# Vault — deployment and operations

Vault is the platform's per-tenant key and secret substrate (**ADR-0015**) and runs **HA in every
topology** (**ADR-0016**). Full design: [`VAULT-ARCHITECTURE.md`](../../../aegis-platform-docs/architecture/VAULT-ARCHITECTURE.md).

> **Why HA even locally.** Vault holds every tenant's signing key and the private material never
> leaves it, which makes Vault a **tier-0 dependency on the token path**. A single-node dev topology
> would stop predicting production behaviour exactly where that matters most, so the Compose stack
> runs a real 3-node Raft cluster.

## Local

```bash
cd compose
docker compose up vault-0 vault-1 vault-2 vault-init
export VAULT_ADDR=http://localhost:8200
docker compose exec vault-0 vault operator raft list-peers   # expect 1 leader + 2 followers
```

`vault-init` initializes and unseals the cluster, enables `transit`, `kv-v2` and `pki` under the
`aegis/` mount, and seeds per-tenant keys and policies for the `dev`, `acme` and `globex` tenants.

**Dev only:** it writes the unseal key and root token to a volume so `docker compose up` is one
command. No deployed environment does this — there Vault auto-unseals via cloud KMS and the root
token is revoked immediately after bootstrap.

## Cloud

```bash
# 1. Provision the unseal key, snapshot store and workload identity
cd terraform/envs/<env> && terraform apply   # includes the vault-unseal module

# 2. Install Vault with the official chart
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault -n aegis -f helm/vault/values-aws.yaml
```

Replace the `REPLACE_WITH_*` placeholders in the values file from the Terraform module outputs
(`kms_key_id`, `role_arn` on AWS; `key_vault_name`, `unseal_key_name`,
`managed_identity_client_id` on Azure).

## What cloud KMS is, and is not

Under ADR-0015 cloud KMS is **demoted to an auto-unseal provider only**. It is no longer an
application dependency on the token path, so a KMS outage *after* unseal does not stop token
signing. That is the opposite of the ADR-0007 arrangement it replaces, where every signing operation
depended on a KMS unwrap.

## Degraded mode

| Vault state | Token verification | Token signing |
|---|---|---|
| Healthy | works | works |
| Unreachable, keys cached | **works** (public JWKS cached) | **fails closed** |
| Unreachable, cold cache | fails | fails closed |

Signing **fails closed** and never falls back to a locally-held key — a fallback key is precisely the
long-lived in-memory secret this design exists to eliminate.

## Backups — read this before an incident

Raft snapshots go to S3 / Blob Storage. **Losing the Raft log means losing every tenant signing key**,
and by design those keys exist nowhere else. Treat snapshot restore as a rehearsed procedure, not a
theoretical one:

```bash
vault operator raft snapshot save  aegis-$(date +%F).snap
vault operator raft snapshot restore aegis-2026-08-26.snap
```

## Per-tenant isolation

| Mode | How | Configure |
|---|---|---|
| `PATH` (Vault OSS) | `aegis/{tenant}/…` + generated per-tenant policy | `aegis.vault.isolation=PATH` |
| `NAMESPACE` (Enterprise) | one Vault namespace per tenant | `aegis.vault.isolation=NAMESPACE` |

Application code is identical either way — only `TenantVaultPaths` differs. The tenant segment is
always **derived** from `TenantContext` server-side and never accepted from a caller.
