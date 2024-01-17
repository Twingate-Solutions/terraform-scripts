##############################################################
#
# Twingate
#
##############################################################

# API token

variable "tg_api_token" {
  type        = string
  description = "Twingate api token"
  sensitive   = true
}

# Network info

variable "tg_network" {
  type        = string
  description = "Twingate network id"
}

# Users

variable "tg_users" {
  type        = set(string)
  description = "List of users that you want to assign to group for access to connector + private resource"
}

# Connector info

variable "tg_log_analytics_version" {
  type        = string
  description = "Twingate connector log analytics version"
}

variable "tg_log_level" {
  type        = string
  description = "Twingate connector log level"
}

# Group Ids

variable "tg_group_ids" {
  type        = set(string)
  description = "Example usage of group ids through a variable"
  sensitive   = true
}