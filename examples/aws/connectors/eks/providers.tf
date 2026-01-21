# examples/eks/providers.tf

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Default tags for all AWS resources
  default_tags {
    tags = {
      Project     = "twingate-connector"
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "twingate-eks"
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  # Optional: Configure exec plugin for authentication
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   command     = "aws"
  #   args = [
  #     "eks",
  #     "get-token",
  #     "--cluster-name",
  #     var.eks_cluster_name,
  #     "--region",
  #     var.aws_region
  #   ]
  # }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    
    # Optional: Configure exec plugin for authentication
    # exec {
    #   api_version = "client.authentication.k8s.io/v1beta1"
    #   command     = "aws"
    #   args = [
    #     "eks",
    #     "get-token",
    #     "--cluster-name",
    #     var.eks_cluster_name,
    #     "--region",
    #     var.aws_region
    #   ]
    # }
  }
}