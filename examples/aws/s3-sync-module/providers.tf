# examples/ecs/providers.tf

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Default tags for all resources
  default_tags {
    tags = {
      Project     = "twingate-connector"
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "twingate-ecs"
    }
  }
}