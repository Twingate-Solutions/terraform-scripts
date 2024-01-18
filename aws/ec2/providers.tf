##############################################################
#
# Terraform providers
#
##############################################################

# Set required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "2.0.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region      = var.aws_region

  // Uncomment if you prefer to NOT copy/paste in the form of (export AWS_ACCESS_KEY_ID="<SOMEVALUE>") to the terminal
  /*
  access_key = var.aws_access_key_id        // AWS access key
  secret_key = var.aws_secret_access_key    // AWS secret key
  token = var.aws_session_token             // temporary AWS session token
  */
}

# Configure Twingate Provider
provider "twingate" {
  api_token   = var.tg_api_token
  network     = var.tg_network
}
