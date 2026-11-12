##############################################################
#
# General
#
##############################################################

variable "app_name" {
  type        = string
  description = "Prefix for cloud resource names and the application label (lowercase, max 16 chars)"
  default     = "tg-tf-demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.app_name))
    error_message = "app_name must start with a lowercase letter, contain only lowercase letters, digits and hyphens, and be at most 16 characters (GCP names and labels)."
  }
}

variable "app_environment" {
  type        = string
  description = "Environment label value (lowercase)"
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.app_environment))
    error_message = "app_environment must be 1-63 lowercase letters, digits, underscores or hyphens (GCP label value)."
  }
}

##############################################################
#
# GCP
#
##############################################################

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID to deploy into"
}

variable "gcp_region" {
  type        = string
  description = "GCP region to deploy into"
  default     = "us-central1"
}

variable "gcp_zone_count" {
  type        = number
  description = "Number of zones in the region for GKE nodes (the regional control plane spans the region)"
  default     = 2

  validation {
    condition     = var.gcp_zone_count >= 1 && var.gcp_zone_count <= 3
    error_message = "gcp_zone_count must be between 1 and 3."
  }
}

variable "gcp_vpc_cidr_block" {
  type        = string
  description = "Address plan for the demo VPC (a /16 is expected; subnets are carved as /24s)"
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.gcp_vpc_cidr_block, 0))
    error_message = "gcp_vpc_cidr_block must be a valid IPv4 CIDR block."
  }
}

variable "gcp_nat_min_ports_per_vm" {
  type        = number
  description = "Cloud NAT ports reserved per node (static allocation, required for endpoint-independent mapping); all pods on a node share them"
  default     = 256

  validation {
    condition     = var.gcp_nat_min_ports_per_vm >= 64 && var.gcp_nat_min_ports_per_vm <= 65536
    error_message = "gcp_nat_min_ports_per_vm must be between 64 and 65536."
  }
}

variable "gcp_gke_release_channel" {
  type        = string
  description = "GKE release channel"
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "EXTENDED"], var.gcp_gke_release_channel)
    error_message = "gcp_gke_release_channel must be RAPID, REGULAR, STABLE or EXTENDED."
  }
}

variable "gcp_gke_machine_type" {
  type        = string
  description = "Machine type for the GKE node pool"
  default     = "e2-medium"
}

variable "gcp_gke_nodes_per_zone" {
  type        = number
  description = "Nodes per zone in the node pool (total = this x gcp_zone_count)"
  default     = 1

  validation {
    condition     = var.gcp_gke_nodes_per_zone >= 1
    error_message = "gcp_gke_nodes_per_zone must be at least 1."
  }
}

variable "gcp_gke_authorized_networks" {
  type        = list(string)
  description = "CIDRs allowed to reach the public control plane endpoint, including where Terraform runs ([] = no restriction; access still requires Google IAM)"
  default     = []
}

variable "gcp_gke_namespace" {
  type        = string
  description = "Kubernetes namespace for the Connectors and the demo nginx Service"
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

  validation {
    condition     = contains(["v1", "v2"], var.tg_log_analytics_version)
    error_message = "The connector Helm chart accepts tg_log_analytics_version \"v1\" or \"v2\"."
  }
}

variable "tg_log_level" {
  type        = string
  description = "Connector TWINGATE_LOG_LEVEL value (3 = default, 7 = debug)"
  default     = "3"

  validation {
    condition     = contains(["3", "4", "6", "7"], var.tg_log_level)
    error_message = "The connector Helm chart supports tg_log_level 3 (error), 4 (warning), 6 (info) or 7 (debug)."
  }
}

variable "tg_helm_chart_version" {
  type        = string
  description = "Twingate connector Helm chart version (https://twingate.github.io/helm-charts)"
  default     = "0.1.35"
}
