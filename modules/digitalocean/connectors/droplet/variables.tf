# Labeling and Tagging
variable "name" {
  type        = string
  default     = ""
  description = "Resource name (e.g., 'app' or 'cluster')"
}

variable "environment" {
  type        = string
  default     = ""
  description = "Environment name (e.g., 'prod', 'dev', 'staging')"
}

variable "label_order" {
  type        = list(any)
  default     = ["name", "environment"]
  description = "Order of labels for resource naming"
}

variable "managedby" {
  type        = string
  default     = "terraform-do-modules"
  description = "Owner or manager of the resources"
}

variable "tags" {
  description = "Tags to apply to droplet resources"
  type        = list(any)
  default     = []
}

# Droplet Configuration
variable "enabled" {
  type        = bool
  default     = true
  description = "Enable droplet creation"
}

variable "region" {
  type        = string
  default     = "blr1"
  description = "DigitalOcean region for resources"
}

variable "droplet_count" {
  type        = number
  default     = 1
  description = "Number of droplets to create"
}

variable "droplet_size" {
  type        = string
  default     = "s-1vcpu-1gb"
  description = "Droplet size slug (e.g., 's-1vcpu-1gb')"
}

variable "image_name" {
  type        = string
  default     = "ubuntu-22-04-x64"
  description = "Operating system image name or slug"
}

variable "resize_disk" {
  type        = bool
  default     = true
  description = "Resize disk when scaling droplet (permanent; RAM/CPU-only resize when false)"
}

variable "user_data" {
  type        = string
  default     = null
  description = "Custom user data script for droplet initialization"
}

variable "volume_ids" {
  type        = list(string)
  default     = []
  description = "Volume IDs to attach to droplet"
}

variable "backup_policy_plan" {
  type        = string
  default     = "weekly"
  description = "Backup policy plan (weekly or monthly)"
}

variable "backup_policy_weekday" {
  type        = string
  default     = "sunday"
  description = "Backup policy weekday (monday, tuesday, wednesday, thursday, friday, saturday, sunday)"
}

variable "backup_policy_hour" {
  type        = number
  default     = 0
  description = "Backup policy hour (0-23)"
}

variable "additional_outbound_http_ports" {
  type        = list(number)
  default     = [8080, 8443]
  description = "Additional HTTP(S) ports for Twingate proxy operations"
}

variable "enable_private_networking" {
  type        = bool
  default     = true
  description = "Enable private VPC networking for enhanced security"
}

variable "snapshot_id" {
  type        = string
  default     = null
  description = "Snapshot ID to restore block storage volume from"
}

# Storage Configuration
variable "backups" {
  type        = bool
  default     = false
  description = "Enable automated backups"
}

variable "block_storage_size" {
  type        = number
  default     = 5
  description = "Block storage volume size in GiB (expandable only)"
}

variable "block_storage_filesystem_label" {
  type        = string
  default     = "data"
  description = "Filesystem label for block storage volume"
}

variable "block_storage_filesystem_type" {
  type        = string
  default     = null
  description = "Filesystem type for block storage (xfs or ext4)"
}

# Networking Configuration
variable "vpc_uuid" {
  type        = string
  default     = ""
  description = "VPC ID for droplet placement"
}

variable "ipv6" {
  type        = bool
  default     = false
  description = "Enable IPv6 networking"
}

variable "floating_ip" {
  type        = bool
  default     = false
  description = "Enable floating IP assignment"
}

# Security and Access
variable "ssh_keys" {
  description = "SSH keys for droplet access"
  type = map(object({
    name       = optional(string)
    public_key = optional(string)
  }))
  default = {
  }
}

variable "enable_firewall" {
  type        = bool
  default     = true
  description = "Enable firewall with default egress-only rules"
}

variable "inbound_rules" {
  type        = any
  default     = []
  description = "Firewall inbound rule configurations (default: none for Twingate outbound-only)"
}

variable "outbound_rule" {
  type = list(object({
    protocol                    = string
    port_range                  = string
    destination_addresses       = optional(list(string), [])
    destination_droplet_ids     = optional(list(string), [])
    destination_kubernetes_ids  = optional(list(string), [])
    destination_tags            = optional(list(string), [])
    destination_load_balancer_uids = optional(list(string), [])
  }))
  default = [
    {
      protocol              = "tcp"
      port_range            = "443"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol              = "tcp"
      port_range            = "30000-31000"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol              = "udp"
      port_range            = "0-65535"
      destination_addresses = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol      = "tcp"
      port_range    = "0-65535"
      destination_tags = ["internal"]
    }
  ]
  description = "Firewall outbound rule configurations (supports addresses, droplets, k8s, tags, and load balancers as destinations)"
}

# Monitoring and Lifecycle
variable "monitoring" {
  type        = bool
  default     = false
  description = "Enable monitoring agent installation"
}

variable "droplet_agent" {
  type        = bool
  default     = false
  description = "Enable DigitalOcean agent for web console access"
}

variable "graceful_shutdown" {
  type        = bool
  default     = false
  description = "Enable graceful shutdown before deletion"
}