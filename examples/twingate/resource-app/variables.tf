# Required fields

variable "tg_api_token" {
  description = "The access key for Twingate API operations"
  type = string
  sensitive = true
}

variable "tg_network" {
  description = "Your Twingate network ID for API operations"
  type = string
}