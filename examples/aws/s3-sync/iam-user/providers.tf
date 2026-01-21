#####################################################
# REQUIRED PROVIDERS
#####################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

#####################################################
# AWS Provider
#####################################################

provider "aws" {
  region = var.aws_region
}