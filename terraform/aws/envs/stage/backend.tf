terraform {
  # Remote state per environment (H8). State holds live secrets (RDS master-secret
  # path, Redis AUTH token) — it must live in the encrypted, locked, access-controlled
  # S3 backend, never an unencrypted local terraform.tfstate.
  #
  # Bootstrap ONCE before the first apply (see terraform/README.md): create the S3
  # bucket (versioned + SSE + Block Public Access) and the DynamoDB lock table, then
  # init with the account-specific bucket name via partial config:
  #
  #   terraform init -backend-config="bucket=aegis-tfstate-<account-id>"
  #
  # CI must pass -backend-config; an init without it fails rather than silently
  # writing local state, which is the guardrail replacing an (inexpressible-in-HCL)
  # "reject local backend" precondition.
  backend "s3" {
    # bucket       — supplied at init via -backend-config (globally unique per account)
    key            = "aws/stage/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "aegis-tflock"
    encrypt        = true
  }
}
