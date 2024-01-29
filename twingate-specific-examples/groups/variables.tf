##############################################################
#
# Twingate
#
##############################################################

### API token

variable "tg_api_token" {
  type        = string
  description = "Twingate api token"
  sensitive   = true
}

### Network info

variable "tg_network" {
  type        = string
  description = "Twingate network id"
}

### Users

# pull in a list of users by id (tg_users are in terraform.tfvars)
variable "tg_users" {
  type        = set(string)
  description = "List of users that you want to assign to group for access to connector + private resource"
}

# alternative way to pull in a list of users, this time by email 
variable "tg_users_email" {
  description = "Variable to pull in a list(string) users by email"
  type = list(string)
  default = ["user1@here.local", "user2@here.local", "user3@here.local"]
}

### Connector info

variable "tg_log_analytics_version" {
  type        = string
  description = "Twingate connector log analytics version"
}

variable "tg_log_level" {
  type        = string
  description = "Twingate connector log level"
}

### Group Ids

variable "tg_group_ids" {
  type        = set(string)
  description = "Example usage of group ids through a variable"
  sensitive   = true
}
