terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Platform    = "aegis"
      Environment = "dev"
      Profile     = "cost-optimized"
      ManagedBy   = "terraform"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

module "platform" {
  source = "../../../modules/aws/stack"

  environment = "dev"
  profile     = "cost-optimized"
  vpc_cidr    = "10.60.0.0/16"

  # M-infra-1: cost profile keeps a public EKS API endpoint — restrict it to the
  # office/VPN egress ranges. TODO(operator): replace the placeholder with real CIDRs
  # before apply (0.0.0.0/0 is rejected by the stack).
  endpoint_public_access_cidrs = ["203.0.113.0/24"] # placeholder — office/VPN egress
}
