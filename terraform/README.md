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
terraform init                   # uncomment backend.tf first for remote state
terraform plan
terraform apply
```

- **State**: each environment has its own state. Bootstrap the S3 bucket +
  DynamoDB table (AWS) / storage account (Azure) once, then uncomment
  `backend.tf`. Never share state between environments.
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
