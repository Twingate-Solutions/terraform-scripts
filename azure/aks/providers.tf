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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "~> 5.2"
    }
  }
}

locals {
  deployment = "Azure AKS"

  common_tags = {
    Application = var.app_name
    Environment = var.app_environment
    ManagedBy   = "terraform"
  }

  # Cluster credentials for the kubernetes and helm providers (AKS local account)
  kube = azurerm_kubernetes_cluster.this.kube_config[0]
}

# Azure credentials come from `az login` or ARM_* env vars.
# subscription_id null = ARM_SUBSCRIPTION_ID, then the az CLI default subscription.
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "kubernetes" {
  host                   = local.kube.host
  client_certificate     = base64decode(local.kube.client_certificate)
  client_key             = base64decode(local.kube.client_key)
  cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    client_certificate     = base64decode(local.kube.client_certificate)
    client_key             = base64decode(local.kube.client_key)
    cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
  }
}

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}
