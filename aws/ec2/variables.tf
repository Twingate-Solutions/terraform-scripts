##############################################################
#
# AWS
#
##############################################################

# Credentials

/*
# Uncomment if you prefer to NOT copy/paste in the form of (export AWS_ACCESS_KEY_ID="<SOMEVALUE>") to the terminal

variable "aws_access_key_id" {
  type        = string
  description = "Command line or programmatic access - access key id"
  sensitive   = true
}

variable "aws_secret_access_key" {
  type        = string
  description = "Command line or programmatic access - secret access key"
  sensitive   = true
}

variable "aws_session_token" {
  type        = string
  description = "Command line or programmatic access - session token"
  sensitive   = true
}
*/

# Tags

variable "app_name" {
  type        = string
  description = "Application Name"
}

variable "app_environment" {
  type        = string
  description = "Application Environment"
}

# VPC

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "aws_vpc_cidr_block" {
  type        = string
  description = "AWS VPC CIDR Block"
}

variable "aws_ssh_key_pair" {
  type        = string
  description = "SSH key pair for EC2 instance"
}

# VPC Peering (Optional)

variable "peer_vpc_id" {
  description = "The ID of the VPC to peer with"
  type        = string
  default     = null
}

variable "enable_vpc_peering" {
  description = "Enable VPC Peering Connection"
  type        = bool
  default     = false
}

variable "peer_region" {
  type        = string
  default     = null
  description = "Region of the VPC to peer with"
}

variable "peer_vpc_cidr_block" {
  type        = string
  default     = null
  description = "Region of the VPC to peer with"
}

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

# Groups

variable "tg_eng_group" {
  type        = string
  description = "Existing engineering group id"
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