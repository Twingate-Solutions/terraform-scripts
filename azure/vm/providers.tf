##############################################################
#
# Terraform & Providers
#
##############################################################

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

locals {
  deployment = "Azure VM"

  common_tags = {
    Application = var.app_name
    Environment = var.app_environment
    ManagedBy   = "terraform"
  }
}

# Azure credentials come from `az login` or ARM_* env vars.
# subscription_id null = ARM_SUBSCRIPTION_ID, then the az CLI default subscription.
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
