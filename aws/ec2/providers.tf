##############################################################
#
# Terraform & Providers
#
##############################################################

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

locals {
  deployment = "AWS EC2"

  common_tags = {
    Application = var.app_name
    Environment = var.app_environment
    ManagedBy   = "terraform"
  }
}

# AWS credentials come from the standard chain (env vars, ~/.aws profile, SSO)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Peer-side provider, only used when enable_vpc_peering = true
provider "aws" {
  alias  = "peer"
  region = coalesce(var.peer_region, var.aws_region)

  default_tags {
    tags = local.common_tags
  }
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
