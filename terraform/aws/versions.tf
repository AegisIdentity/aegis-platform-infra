terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  # Configure remote state per environment (S3 + DynamoDB lock) before use:
  # backend "s3" { bucket = "aegis-tfstate" key = "aws/terraform.tfstate" region = "eu-west-1" dynamodb_table = "aegis-tflock" }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Platform    = "aegis"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
