##############################################################
#
# Terraform & Providers
#
##############################################################

terraform {
  required_version = ">= 1.9"

  required_providers {
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
