terraform {
  # Remote state per environment. Bootstrap the bucket + lock table once,
  # then uncomment. State is isolated per environment by key.
  # backend "s3" {
  #   bucket         = "aegis-tfstate"
  #   key            = "aws/test/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "aegis-tflock"
  #   encrypt        = true
  # }
}
