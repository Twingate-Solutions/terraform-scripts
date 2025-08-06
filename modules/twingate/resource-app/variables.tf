# Required fields

variable "name" {
  description = "Name of the Twingate resource"
  type        = string
}

variable "remote_network_id" {
  description = "ID of the remote network"
  type        = string
}

variable "resources" {
  description = "List of Twingate resources"
  type = list(object({
    address = string
    alias   = optional(string, null)
  }))

  validation {
    condition     = length(var.resources) > 0 && alltrue([for resource in var.resources : can(resource.address) && resource.address != ""])
    error_message = "The 'resources' list must contain at least one object, and each object must have a non-empty 'address'."
  }
}

# Optional fields

variable "access_group" {
  description = "List of group access configurations"
  type = list(object({
    group_id = string
    #security_policy_id = optional(string, null)
    #usage_based_autolock_duration_days = optional(number, null)
  }))
  default = []
}

variable "access_service" {
  description = "List of service account access configurations"
  type = list(object({
    service_account_id = string
  }))
  default = []
}

variable "alias" {
  description = "FQDN alias for resources"
  type = string
  default = null
}

variable "is_active" {
  description = "Set resource to active or not"
  type = bool
  default = null
}

variable "is_authoritative" {
  description = "Override existing group assignments"
  type = bool
  default = null
}

variable "is_browser_shortcut_enabled" {
  description = "Enable browser shortcut?"
  type        = bool
  default = null
}

variable "is_visible" {
  description = "Should the resource be visible?"
  type        = bool
  default = null
}

variable "protocols" {
  description = "Protocol settings for the Twingate resource"
  type = object({
    allow_icmp = optional(bool, true)
    tcp = optional(object({
      policy = optional(string, "ALLOW_ALL")
      ports  = optional(set(string), [])
    }), {})

    udp = optional(object({
      policy = optional(string, "ALLOW_ALL")
      ports  = optional(set(string), [])
    }), {})
  })
  default = {}
}

variable "security_policy_id" {
  description = "Security policy ID to attach"
  type        = string
  default = null
}