# aegis-platform-infra — working notes

Local stack (Docker Compose), Terraform (AWS + Azure), Helm, CI.

- `compose/` runs the core services locally. OIDC issuer is the in-network hostname — see README.
- Terraform is modular: building blocks in `terraform/modules/<cloud>/`, composed by each cloud's
  `stack` module; envs are thin roots in `terraform/{aws,azure}/envs/{dev,test,stage,prod}` with
  isolated state. dev/test = `cost-optimized` profile, stage/prod = `hardened` (identical, max
  security, least privilege). Profile differences live ONLY in the stack modules' `profiles` map —
  never fork env roots. All 8 roots `terraform validate` clean; `plan`/`apply` still needs remote
  state bootstrap + credentials (see `terraform/README.md`).
- `helm/aegis-service` is a reusable chart (not `helm lint`-verified in CI yet).
- Keep the database-per-service rule (ADR-0002); never point two services at one database.
