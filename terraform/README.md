# Aegis platform — Terraform

Modular IaC for the Aegis platform on AWS and Azure. Reusable building blocks
live in `modules/<cloud>/`, and each environment is a thin root that composes
them through the per-cloud `stack` module.

```
terraform/
├── modules/
│   ├── aws/
│   │   ├── network/    VPC, subnets, NAT strategy, flow logs
│   │   ├── kms/        CMKs with rotation (signing + data-store keys)
│   │   ├── eks/        EKS, IRSA, IMDSv2-only nodes, control-plane logs
│   │   ├── postgres/   RDS 16, force_ssl, SG locked to EKS nodes
│   │   ├── redis/      ElastiCache, TLS + AUTH (token in Secrets Manager)
│   │   ├── kafka/      MSK, TLS in transit, optional SASL/IAM
│   │   ├── ecr/        Immutable, scan-on-push repos + lifecycle policy
│   │   ├── irsa/       Generic least-privilege pod-identity role factory
│   │   └── stack/      Composition + the cost-optimized/hardened profiles
│   └── azure/
│       ├── network/    VNet, subnets, NSGs, private DNS zones
│       ├── aks/        AKS, Workload Identity, Calico, optional private API
│       ├── postgres/   Flexible Server 16, VNet-integrated, per-service DBs
│       ├── redis/      TLS-only cache, optional private endpoint
│       ├── eventhubs/  Kafka-protocol namespace, optional private endpoint
│       ├── acr/        No-admin registry, optional private endpoint
│       ├── keyvault/   RBAC-only vault, optional private endpoint
│       ├── workload-identity/  UAI + federated credential + role assignments
│       └── stack/      Composition + the cost-optimized/hardened profiles
├── aws/envs/{dev,test,stage,prod}/    one state per environment
└── azure/envs/{dev,test,stage,prod}/  one state per environment
```

## Environments and profiles

Every environment root passes exactly two decisions to the stack: its name
and its **profile**. Everything else derives from the profile, so stage and
prod cannot drift apart.

| Environment | Profile | Intent |
|---|---|---|
| dev, test | `cost-optimized` | Cheap to run, safe to tear down |
| stage, prod | `hardened` | Identical maximum-security setup |

**cost-optimized** (dev/test): single NAT gateway, spot/burstable compute,
single-AZ data tier, short retention, public (CIDR-restrictable) cluster API,
AWS/Azure-managed encryption keys, immediate secret/vault teardown.

**hardened** (stage/prod): private-only cluster API, NAT per AZ, multi-AZ /
zone-redundant everything, CMKs with rotation for every data store, VPC flow
logs and full control-plane audit logs with 1-year retention, IAM-authenticated
Kafka (AWS) / private endpoints for every data plane (Azure), deletion
protection and purge protection, 30–35-day backups.

**Never relaxed in any profile**: TLS-only data planes (Postgres `force_ssl`,
Redis TLS+AUTH, Kafka TLS), data-tier ingress locked to the cluster's node
security group / subnet, least-privilege pod identities (IRSA / Workload
Identity), immutable scanned images, no admin accounts, no public database
access, encryption at rest.

## Usage

```sh
cd terraform/aws/envs/dev        # or any other environment

# Remote state is REQUIRED (H8): backend.tf declares an S3/azurerm backend with a
# partial config. Bootstrap the state store once (below), then pass the account-specific
# bucket / storage account at init:
terraform init -backend-config="bucket=aegis-tfstate-<account-id>"          # AWS
# terraform init -backend-config="storage_account_name=aegistfstate<suffix>"  # Azure

terraform plan
terraform apply
```

### State bootstrap (do this once, before any apply — H8)

The backends are **enabled**: state carries live secrets (Redis AUTH token, RDS
master-secret path, Azure Postgres admin password), so it must never land in an
unencrypted local `terraform.tfstate`. Bootstrap the backing store first:

- **AWS**: create an S3 bucket (versioning on, SSE, Block Public Access on) and a
  DynamoDB lock table named `aegis-tflock`. The bucket name is globally unique, so
  each env's `backend.tf` leaves `bucket` to be supplied via
  `-backend-config="bucket=..."` at init. `key`/`region`/`encrypt`/`dynamodb_table`
  are fixed per env.
- **Azure**: create a resource group `aegis-tfstate`, a storage account (blob
  versioning + soft delete, public access disabled, Azure AD auth) and a `tfstate`
  container. The storage account name is globally unique, so supply it via
  `-backend-config="storage_account_name=..."` at init.

`terraform init` without `-backend-config` fails rather than silently writing local
state — that refusal is the guardrail (a "reject local backend" precondition is not
expressible in HCL). **CI must pass `-backend-config` and should gate on remote state
being configured.** Never share state between environments.

### Required per-environment inputs (no defaults — plan fails until set)

- **stage/prod (Azure)** — `admin_group_object_ids` (H9): the Entra ID group object
  IDs granted Azure RBAC cluster admin. No default, so `plan` fails until you supply
  the real prod/stage group GUIDs (e.g. `TF_VAR_admin_group_object_ids='["<guid>"]'`).
  Empty is rejected for the hardened profile — it would re-enable static local admin
  kubeconfigs.
- **dev/test (AWS)** — `endpoint_public_access_cidrs` (M-infra-1): the cost profile
  exposes a public EKS API endpoint, so it must be narrowed to office/VPN CIDRs. The
  roots ship a placeholder (`203.0.113.0/24`); replace it before apply. `0.0.0.0/0`
  is rejected.

### Detection & audit (M-infra-4)

The hardened profile wires an **audit module** (`modules/{aws,azure}/audit`): AWS
CloudTrail + GuardDuty + Config; Azure Log Analytics + diagnostic settings for
AKS/Key Vault/ACR/Postgres + Microsoft Defender plans. These are account/subscription
-scoped singletons — if a landing zone already owns them centrally, omit the module
(set the profile's `enable_audit` to false or remove the `module "audit"` call) to
avoid conflicts. See each module's header for prerequisites.

- **State**: each environment has its own state (isolated by backend `key`). Never
  share state between environments.
- **Credentials**: standard `AWS_PROFILE` / `az login` + `ARM_SUBSCRIPTION_ID`.
  The identity running apply needs rights to create IAM roles / role
  assignments (least-privilege runbooks live with the pipeline).
- **Hardened caveats** (by design): the cluster API is private — plan/apply
  kubectl steps run from a VPN/bastion/in-network runner; ACR/Key Vault have
  public access disabled — CI pushes images and reads secrets over private
  connectivity or scoped, temporary network exceptions.
- **Naming**: ACR, Key Vault, Event Hubs and Postgres names are globally
  unique in Azure — if a name collides, adjust the prefix in the stack call.

## Verification status

`terraform fmt` and `terraform init -backend=false && terraform validate` pass
for all 8 environment roots. `plan`/`apply` require cloud credentials and have
not been run from this repo — review plans environment-by-environment before
first apply.
