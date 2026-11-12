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
# Azure
#
##############################################################

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID (null = ARM_SUBSCRIPTION_ID, then the az CLI default subscription)"
  default     = null
}

variable "azure_location" {
  type        = string
  description = "Azure region to deploy into"
  default     = "eastus"
}

variable "azure_vnet_cidr_block" {
  type        = string
  description = "Address space for the demo VNet (a /16 is expected; the private subnet is carved as a /24)"
  default     = "10.45.0.0/16"
}

variable "azure_zones" {
  type        = list(string)
  description = "Availability zones for the AKS node pool ([] for regions without zones)"
  default     = ["1", "2", "3"]
}

variable "azure_aks_kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version (null = AKS default)"
  default     = null
}

variable "azure_aks_node_count" {
  type        = number
  description = "Nodes in the AKS system node pool"
  default     = 2

  validation {
    condition     = var.azure_aks_node_count >= 1
    error_message = "azure_aks_node_count must be at least 1."
  }
}

variable "azure_aks_node_vm_size" {
  type        = string
  description = "VM size for the AKS system node pool (system pools need at least 2 vCPU / 4 GB)"
  default     = "Standard_D2s_v5"
}

variable "azure_aks_namespace" {
  type        = string
  description = "Kubernetes namespace for the Connector releases and the demo nginx service"
  default     = "tg-tf-demo"
}

variable "azure_aks_api_authorized_ip_ranges" {
  type        = set(string)
  description = "CIDRs allowed to reach the AKS API server ([] = unrestricted). Must include where Terraform runs; the NAT egress IP is added automatically"
  default     = []

  validation {
    condition     = alltrue([for c in var.azure_aks_api_authorized_ip_ranges : can(cidrhost(c, 0))])
    error_message = "azure_aks_api_authorized_ip_ranges entries must be CIDRs, e.g. \"203.0.113.10/32\"."
  }
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
  description = "Twingate connector Helm chart version (null = latest at apply time)"
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
  description = "Connector TWINGATE_LOG_LEVEL value (3 = default, 7 = debug). Helm chart supports 3, 4, 6, 7"
  default     = "3"

  validation {
    condition     = contains(["3", "4", "6", "7"], var.tg_log_level)
    error_message = "tg_log_level must be one of 3, 4, 6, 7 (the Helm chart's error, warning, info, debug)."
  }
}
