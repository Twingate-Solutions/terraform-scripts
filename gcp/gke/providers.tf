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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

locals {
  deployment = "GCP GKE"

  # GCP resource names are unique per project; the suffix lets sibling gcp/* modules share a project
  name_prefix = "${var.app_name}-gke"

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

# Short-lived OAuth token of the identity running Terraform; no kubeconfig or
# gke-gcloud-auth-plugin needed. The token lasts ~1 hour, long enough for one apply.
data "google_client_config" "current" {}

locals {
  gke_host           = "https://${google_container_cluster.this.endpoint}"
  gke_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

provider "kubernetes" {
  host                   = local.gke_host
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = local.gke_ca_certificate
}

# Helm provider 3.x: `kubernetes` is an object attribute, not a block
provider "helm" {
  kubernetes = {
    host                   = local.gke_host
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = local.gke_ca_certificate
  }
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
