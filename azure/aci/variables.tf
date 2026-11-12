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
  default     = "10.44.0.0/16"
}

variable "azure_aci_connector_cpu" {
  type        = number
  description = "vCPU per Connector container group"
  default     = 1
}

variable "azure_aci_connector_memory" {
  type        = number
  description = "Memory (GB) per Connector container group"
  default     = 2
}

variable "azure_aci_registry_username" {
  type        = string
  description = "Docker Hub username for authenticated Connector image pulls (null = anonymous; anonymous pulls can hit Docker Hub rate limits)"
  default     = null
}

variable "azure_aci_registry_password" {
  type        = string
  description = "Docker Hub password or personal access token (required with azure_aci_registry_username)"
  default     = null
  sensitive   = true
}

variable "azure_dns_zone_name" {
  type        = string
  description = "Azure Private DNS zone name; the private resource registers as web-aci.<zone>"
  default     = "tg-tf-demo.int"
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
