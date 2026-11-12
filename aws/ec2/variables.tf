##############################################################
#
# General
#
##############################################################

variable "app_name" {
  type        = string
  description = "Prefix for cloud resource names and the Application tag"
  default     = "tg-tf-demo"
}

variable "app_environment" {
  type        = string
  description = "Environment tag value"
  default     = "demo"
}

##############################################################
#
# AWS
#
##############################################################

variable "aws_region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "aws_vpc_cidr_block" {
  type        = string
  description = "CIDR block for the demo VPC (a /16 is expected; subnets are carved as /24s)"
  default     = "10.37.0.0/16"
}

variable "aws_az_count" {
  type        = number
  description = "Number of availability zones to spread public/private subnets across"
  default     = 2

  validation {
    condition     = var.aws_az_count >= 1 && var.aws_az_count <= 4
    error_message = "aws_az_count must be between 1 and 4."
  }
}

variable "aws_ssh_key_pair" {
  type        = string
  description = "Existing EC2 key pair name for the Connector and private resource instances (null = no key)"
  default     = null
}

variable "aws_connector_subnet_type" {
  type        = string
  description = "Subnet type the Connector instances are placed in: private (behind fck-nat) or public"
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.aws_connector_subnet_type)
    error_message = "aws_connector_subnet_type must be \"private\" or \"public\"."
  }
}

variable "aws_connector_instance_type" {
  type        = string
  description = "Instance type for the Connector instances"
  default     = "t3a.micro"
}

variable "aws_dns_zone_name" {
  type        = string
  description = "Route 53 private hosted zone name; the private resource is web-ec2.<zone>"
  default     = "tg-tf-demo.int"
}

##############################################################
#
# AWS - VPC Peering (Optional)
#
##############################################################

variable "enable_vpc_peering" {
  type        = bool
  description = "Peer the demo VPC with an existing VPC in the same account"
  default     = false
}

variable "peer_vpc_id" {
  type        = string
  description = "ID of the existing VPC to peer with (required when enable_vpc_peering = true)"
  default     = null
}

variable "peer_region" {
  type        = string
  description = "Region of the peer VPC (null = same region as aws_region)"
  default     = null
}

variable "peer_vpc_cidr_block" {
  type        = string
  description = "CIDR block of the peer VPC (required when enable_vpc_peering = true)"
  default     = null
}

variable "peer_route_table_id" {
  type        = string
  description = "Peer VPC route table to add the return route to (null = add the return route manually)"
  default     = null
}

##############################################################
#
# Twingate
#
##############################################################

variable "tg_api_token" {
  type        = string
  description = "Twingate API token (Read, Write & Provision). Null = read from TWINGATE_API_TOKEN"
  default     = null
  sensitive   = true
}

variable "tg_network" {
  type        = string
  description = "Twingate network slug, e.g. \"autoco\" for autoco.twingate.com"
}

variable "tg_connector_count" {
  type        = number
  description = "Number of Connectors to deploy (2+ recommended for redundancy)"
  default     = 2

  validation {
    condition     = var.tg_connector_count >= 1
    error_message = "tg_connector_count must be at least 1."
  }
}

variable "tg_users" {
  type        = set(string)
  description = "Twingate user IDs added to the demo group (from <slug>.twingate.com/users/<id>)"
  default     = []
}

variable "tg_existing_group_ids" {
  type        = set(string)
  description = "Existing Twingate group IDs to also grant access to the demo resource"
  default     = []
}

variable "tg_security_policy_name" {
  type        = string
  description = "Existing Twingate security policy name to apply to the resource (null = Default Policy)"
  default     = null
}

variable "tg_autolock_duration" {
  type        = string
  description = "Usage-based auto-lock duration for group access, e.g. \"30d\" (null = no access policy)"
  default     = "30d"
}

variable "tg_create_service_account" {
  type        = bool
  description = "Create a Twingate service account + key with access to the demo resource"
  default     = false
}

variable "tg_log_analytics_version" {
  type        = string
  description = "Connector TWINGATE_LOG_ANALYTICS value"
  default     = "v2"
}

variable "tg_log_level" {
  type        = string
  description = "Connector TWINGATE_LOG_LEVEL value (3 = default, 7 = debug)"
  default     = "3"
}
