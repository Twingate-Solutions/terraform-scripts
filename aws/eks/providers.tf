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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

locals {
  deployment = "AWS EKS"

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

# api_token falls back to the TWINGATE_API_TOKEN environment variable when null
provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}

# Cluster auth: `aws eks get-token` runs on every provider call, so the token never
# expires mid-apply (aws_eks_cluster_auth tokens last 15 minutes, shorter than a
# cluster + node group create). The AWS CLI uses the same credential chain as the
# aws provider; that identity is the cluster creator and gets cluster-admin via
# bootstrap_cluster_creator_admin_permissions.
locals {
  eks_exec_args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.aws_region, "--output", "json"]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.eks_exec_args
  }
}

# helm provider 3.x: `kubernetes` and `exec` are attributes, not blocks
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.eks_exec_args
    }
  }
}
