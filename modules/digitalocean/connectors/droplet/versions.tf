# Terraform version
terraform {
  required_version = ">= 1.14.3"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.73.0"
    }
  }
}