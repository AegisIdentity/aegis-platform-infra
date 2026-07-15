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
      Environment = "test"
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

  environment = "test"
  profile     = "cost-optimized"
  vpc_cidr    = "10.61.0.0/16"
}
