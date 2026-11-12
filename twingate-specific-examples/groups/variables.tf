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

variable "name_prefix" {
  type        = string
  description = "Prefix for the Twingate objects this example creates"
  default     = "TF Groups Example"
}

variable "tg_group_ids" {
  type        = set(string)
  description = "Example 2: existing group IDs to grant access, e.g. [\"R3JvdXA6MTIzNDU=\"]"
  default     = []
}

variable "tg_users_email" {
  type        = set(string)
  description = "Example 3: emails of users to create (invites are sent) and add to a new group"
  default     = []
}
