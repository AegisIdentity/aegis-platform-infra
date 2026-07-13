# aegis-platform-infra — working notes

Local stack (Docker Compose), Terraform (AWS + Azure), Helm, CI.

- `compose/` runs the core services locally. OIDC issuer is the in-network hostname — see README.
- `terraform/aws` and `terraform/azure` both `terraform validate` clean but are **skeletons** (no
  remote state, ingress/TLS, least-privilege IAM, or external-secrets yet). Do not `apply` as-is.
- `helm/aegis-service` is a reusable chart (not `helm lint`-verified in CI yet).
- Keep the database-per-service rule (ADR-0002); never point two services at one database.
