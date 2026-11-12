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
  default     = "10.39.0.0/16"
}

variable "aws_az_count" {
  type        = number
  description = "Number of availability zones to spread public/private subnets across (EKS needs at least 2)"
  default     = 2

  validation {
    condition     = var.aws_az_count >= 2 && var.aws_az_count <= 4
    error_message = "aws_az_count must be between 2 and 4 (EKS requires subnets in at least two AZs)."
  }
}

variable "aws_eks_kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version"
  default     = "1.36"
}

variable "aws_eks_node_instance_type" {
  type        = string
  description = "Instance type for the managed node group"
  default     = "t3.small"
}

variable "aws_eks_node_count" {
  type        = number
  description = "Number of worker nodes (fixed size; spread across the private subnets)"
  default     = 2

  validation {
    condition     = var.aws_eks_node_count >= 1
    error_message = "aws_eks_node_count must be at least 1."
  }
}

variable "aws_eks_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public EKS API endpoint. Default 0.0.0.0/0 is open to the internet: set your egress IP/CIDR, which must include where Terraform runs"
  default     = ["0.0.0.0/0"]
}

variable "aws_eks_namespace" {
  type        = string
  description = "Kubernetes namespace for the Connector Helm releases and the demo nginx service"
  default     = "twingate-demo"
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
  description = "Twingate Connector container image (<repository>:<tag>)"
  default     = "twingate/connector:1"

  validation {
    condition     = can(regex("^.+:[^:/]+$", var.tg_connector_image))
    error_message = "tg_connector_image must be <repository>:<tag>."
  }
}

variable "tg_helm_chart_version" {
  type        = string
  description = "Twingate connector Helm chart version (https://twingate.github.io/helm-charts)"
  default     = "0.1.35"
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
  description = "Connector TWINGATE_LOG_ANALYTICS value (Helm chart accepts v1 or v2)"
  default     = "v2"

  validation {
    condition     = contains(["v1", "v2"], var.tg_log_analytics_version)
    error_message = "tg_log_analytics_version must be \"v1\" or \"v2\" for the Helm chart."
  }
}

variable "tg_log_level" {
  type        = string
  description = "Connector TWINGATE_LOG_LEVEL value (3 = default, 7 = debug)"
  default     = "3"

  # The Helm chart sets TWINGATE_LOG_LEVEL itself from a named level; only these map
  validation {
    condition     = contains(["3", "4", "6", "7"], var.tg_log_level)
    error_message = "tg_log_level must be \"3\" (error), \"4\" (warning), \"6\" (info) or \"7\" (debug) for the Helm chart."
  }
}
