terraform {
  # Remote state per environment (H8). Even dev/test state can contain a Redis AUTH
  # token and DB credential paths — keep it in the encrypted, locked S3 backend rather
  # than an unencrypted local terraform.tfstate.
  #
  # Bootstrap ONCE before the first apply (see terraform/README.md): create the S3
  # bucket (versioned + SSE + Block Public Access) and the DynamoDB lock table, then
  # init with the account-specific bucket name via partial config:
  #
  #   terraform init -backend-config="bucket=aegis-tfstate-<account-id>"
  #
  # CI must pass -backend-config; an init without it fails rather than silently
  # writing local state.
  backend "s3" {
    # bucket       — supplied at init via -backend-config (globally unique per account)
    key            = "aws/test/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "aegis-tflock"
    encrypt        = true
  }
}
