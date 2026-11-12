##############################################################
#
# Terraform & Providers
#
##############################################################

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

locals {
  deployment = "GCP GCE Container"

  # GCP resource names are unique per project; the suffix lets sibling gcp/* modules share a project
  name_prefix = "${var.app_name}-cos"

  common_labels = {
    application = var.app_name
    environment = var.app_environment
    managed-by  = "terraform"
  }
}

# GCP credentials come from Application Default Credentials
# (`gcloud auth application-default login` or GOOGLE_APPLICATION_CREDENTIALS)
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
