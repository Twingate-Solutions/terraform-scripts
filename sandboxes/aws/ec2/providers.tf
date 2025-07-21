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
      version = "~> 5.63.1"
    }
    twingate = {
      source  = "twingate/twingate"
      version = "3.0.10"
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

provider "aws" {
  alias  = "us-west-1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
}

# Configure Twingate Provider
provider "twingate" {
  api_token   = var.tg_api_token
  network     = var.tg_network
}
