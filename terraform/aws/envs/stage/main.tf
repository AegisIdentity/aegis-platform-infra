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
      Environment = "stage"
      Profile     = "hardened"
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

  environment = "stage"
  profile     = "hardened"
  vpc_cidr    = "10.62.0.0/16"
}
