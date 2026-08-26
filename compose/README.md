# Local stack

Runs the **whole platform**: 12 services, Postgres, Redis, Kafka, and a 3-node HashiCorp Vault
cluster.

```bash
# 1. Build every service jar (installs BOM + commons to ~/.m2 first)
scripts/build-all.sh

# 2. Start everything
cd compose && docker compose up -d

# 3. Verify it actually works, end to end
../scripts/e2e-agent-flow.sh
```

## What comes up

| Service | Port | Notes |
|---|---|---|
| `edge-gateway` | 8080 | The public front door. Everything below is reachable through it. |
| `authorization-server` | 9000 | OIDC/OAuth2, token exchange, DPoP, ID-JAG |
| `tenant-service` | 9101 | tenants, domains, per-tenant agent policy |
| `identity-service` | 9102 | users, groups, **agent principals** |
| `mfa-webauthn-service` | 9103 | passkeys / TOTP |
| `saml-idp-service` | 9104 | SAML 2.0 IdP |
| `social-broker-service` | 9105 | social + inbound federation |
| `scim-provisioning-service` | 9106 | SCIM 2.0 |
| `admin-api-service` | 9107 | admin API, **PDP**, **Vault broker** |
| `agent-registry-service` | 9108 | content-addressed tool registry |
| `threat-analysis-service` | 9109 | agent behavioural detection |
| `admin-console` | 3000 | SPA |
| `vault-0/1/2` | 8200-8202 | HA Raft cluster |

## Vault

Three nodes, not one — deliberately. Vault is a tier-0 dependency on the token path, so a
single-node dev topology would stop predicting production exactly where it matters most. `vault-init`
bootstraps the cluster, enables `transit` / `kv-v2` / `pki`, seeds per-tenant keys and policies, and
issues a **scoped** platform token.

```bash
docker compose exec vault-0 vault status
../scripts/e2e-agent-flow.sh          # section 9 prints the raft peer list
```

`admin-api-service` reads that token from a **file** on a shared volume, not an environment variable:
an env var leaks into `docker inspect`, process listings and crash dumps, and a file is the shape
both Kubernetes and the Vault Agent use — so dev matches production. The token carries the
`aegis-platform` policy, not root, so a compromised admin-api cannot seal the cluster or rewrite
policies.

**Vault-backed token signing is off by default** (`aegis.vault.signing.enabled`). That is the
migration flag from `VAULT-ARCHITECTURE.md` §7: the new `kid` must appear in JWKS before it signs and
the old one must stay verifiable until its tokens expire, so the cutover is a reversible rotation.

## The end-to-end check

`scripts/e2e-agent-flow.sh` drives the real stack through the real gateway. It covers what unit tests
structurally cannot: route ordering, tenant propagation across a network hop, scope enforcement by a
different process than the one that minted the token, and whether audit events actually reach the
detection consumer over Kafka.

It is a script rather than a Maven test because it needs the whole stack running — which is not
something a unit test should ever require.

## Notes

- Everything binds to **loopback only**; no datastore is LAN-reachable.
- Add `127.0.0.1 authorization-server` to `/etc/hosts` for browser flows, so the issuer string is
  identical for the browser and for in-cluster services.
- `docker compose down -v` wipes Postgres *and* the Vault volumes — the cluster re-bootstraps on the
  next `up`.
