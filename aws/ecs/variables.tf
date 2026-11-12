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
  default     = "10.38.0.0/16"
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

variable "aws_connector_subnet_type" {
  type        = string
  description = "Subnet type the Connector tasks run in: private (behind fck-nat) or public"
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.aws_connector_subnet_type)
    error_message = "aws_connector_subnet_type must be \"private\" or \"public\"."
  }
}

variable "aws_connector_cpu" {
  type        = number
  description = "Fargate CPU units per Connector task"
  default     = 1024
}

variable "aws_connector_memory" {
  type        = number
  description = "Fargate memory (MiB) per Connector task"
  default     = 2048
}

variable "aws_dns_zone_name" {
  type        = string
  description = "Cloud Map private DNS namespace; the private resource registers as web-ecs.<zone>"
  default     = "tg-tf-demo.int"
}

variable "aws_log_retention_days" {
  type        = number
  description = "CloudWatch log retention for Connector and resource containers"
  default     = 7
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

variable "tg_connector_image" {
  type        = string
  description = "Twingate Connector container image"
  default     = "twingate/connector:1"
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
