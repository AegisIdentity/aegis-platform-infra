# aegis-platform-infra

Local stack (Docker Compose), cloud IaC (Terraform for AWS & Azure), Kubernetes packaging (Helm),
and the CI pipeline template for the Aegis Identity Platform.

## Local — Docker Compose
```bash
# 1. Build the shared artifacts + service fat jars (installs parent/commons to ~/.m2).
./scripts/build-all.sh

# 2. Bring up Postgres, Redis, Kafka, and the core services.
cd compose && docker compose up --build

# 3. Try it (from the host, against the containerized authorization-server):
curl -s localhost:9000/.well-known/openid-configuration | jq .
curl -s -u aegis-dev-m2m:dev-only-change-me \
  -d grant_type=client_credentials -d scope=identity:users:read \
  localhost:9000/oauth2/token | jq .
```
> **OIDC issuer note.** The issuer is the in-network hostname `http://authorization-server:9000` so
> resource servers validate tokens against a URL that resolves identically inside the compose network.
> This is the standard docker-compose OIDC pattern; for host-based browser flows in dev, add
> `127.0.0.1 authorization-server` to `/etc/hosts` (or run everything through the gateway on `:8080`).

`compose/init/10-create-databases.sql` creates one database per service (database-per-service,
ADR-0002). The core services (`authorization-server`, `identity-service`, `tenant-service`,
`edge-gateway`) plus the **`admin-console`** front-end (nginx SPA on **http://localhost:3000**) run;
the remaining backend services are scaffolds and are added to compose as they mature.

> **Front-end sign-in in compose.** The SPA (browser) uses the OIDC issuer
> `http://authorization-server:9000`, which must resolve identically for the browser and the
> in-cluster services — add `127.0.0.1 authorization-server` to your `/etc/hosts`, then open the
> console at `http://localhost:3000`. Its redirect URIs are pre-registered on the `aegis-dev-spa`
> client. The `admin-console` image builds itself (Node → nginx); it does not use `build-all.sh`.

## Cloud — Terraform
Two self-contained roots sharing conventions; both `terraform validate` cleanly.
```bash
cd terraform/aws   && terraform init && terraform plan   # EKS, RDS, ElastiCache, MSK, ECR, KMS
cd terraform/azure && terraform init && terraform plan   # AKS, PG Flexible, Cache, Event Hubs, ACR, Key Vault
```
| Concern | AWS (`terraform/aws`) | Azure (`terraform/azure`) |
|---|---|---|
| Kubernetes | EKS (managed node group, IRSA) | AKS (Workload Identity, Calico NetworkPolicy) |
| PostgreSQL | RDS 16 (Multi-AZ in prod) | Flexible Server 16 (private) |
| Redis | ElastiCache 7 (encrypted) | Cache for Redis Premium |
| Kafka | MSK (TLS) | Event Hubs (Kafka endpoint) |
| Registry | ECR (immutable, scan-on-push) | ACR Premium |
| Secrets/keys | Secrets Manager + KMS | Key Vault |

> **Status: skeletons, not apply-ready production.** They validate and cover the core resources, but
> before a real `apply` you must add: remote state backends, IAM/RBAC least-privilege bindings,
> ingress controllers + TLS/WAF, external-secrets/CSI wiring, private endpoints, and observability.

## Kubernetes — Helm
`helm/aegis-service` is a reusable chart (Deployment, Service, HPA, default-deny NetworkPolicy,
non-root + read-only-rootfs security context). One values file per service:
```bash
helm install identity helm/aegis-service -f values-identity.yaml
```
> Not `helm lint`-verified in the authoring environment (helm not installed there) — run `helm lint`
> and `helm template` before use.

## CI
`ci/service-ci.yml` is the per-service pipeline template (→ each repo's `.github/workflows/ci.yml`):
build → unit+Testcontainers tests → coverage gate → SpotBugs SAST → OWASP dependency CVE scan →
container build → Trivy image scan → sign/push on `main`.
