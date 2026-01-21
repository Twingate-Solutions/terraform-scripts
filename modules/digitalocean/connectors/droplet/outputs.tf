# Droplet Core Information
output "id" {
  value       = digitalocean_droplet.main[*].id
  description = "Unique identifier of the droplet"
}

output "urn" {
  value       = digitalocean_droplet.main[*].urn
  description = "Uniform resource name of the droplet"
}

output "name" {
  value       = digitalocean_droplet.main[*].name
  description = "Name of the droplet"
}

output "status" {
  value       = digitalocean_droplet.main[*].status
  description = "Current status of the droplet (new, active, etc.)"
}

# Droplet Specifications
output "size" {
  value       = digitalocean_droplet.main[*].size
  description = "Instance size slug"
}

output "disk" {
  value       = digitalocean_droplet.main[*].disk
  description = "Root disk size in GB"
}

output "vcpus" {
  value       = digitalocean_droplet.main[*].vcpus
  description = "Number of virtual CPUs"
}

output "locked" {
  value       = digitalocean_droplet.main[*].locked
  description = "Whether the droplet is locked"
}

# Network Configuration
output "region" {
  value       = digitalocean_droplet.main[*].region
  description = "Region where droplet is deployed"
}

output "ipv4_address" {
  value       = digitalocean_droplet.main[*].ipv4_address
  description = "Public IPv4 address of the droplet"
}

output "ipv4_address_private" {
  value       = digitalocean_droplet.main[*].ipv4_address_private
  description = "Private IPv4 address (VPC networking)"
}

output "ipv6" {
  value       = digitalocean_droplet.main[*].ipv6
  description = "Whether IPv6 is enabled"
}

output "ipv6_address" {
  value       = digitalocean_droplet.main[*].ipv6_address
  description = "Public IPv6 address of the droplet"
}

# Pricing Information
output "price_hourly" {
  value       = digitalocean_droplet.main[*].price_hourly
  description = "Hourly billing rate in USD"
}

output "price_monthly" {
  value       = digitalocean_droplet.main[*].price_monthly
  description = "Monthly billing rate in USD"
}

# Resource Tagging
output "tags" {
  value       = digitalocean_droplet.main[*].tags
  description = "Tags applied to the droplet for organization and billing"
}

# SSH Keys
output "ssh_keys" {
  description = "SSH keys configured for droplet access"
  value = {
    for key, ssh_key in digitalocean_ssh_key.ssh_keys :
    key => {
      id          = ssh_key.id
      name        = ssh_key.name
      fingerprint = ssh_key.fingerprint
      public_key  = ssh_key.public_key
    } if var.ssh_keys[key] != null
  }
}

# Storage and Networking
output "volume_ids" {
  value       = digitalocean_volume.main[*].id
  description = "IDs of attached block storage volumes"
}

output "public_ip_address" {
  value       = try(digitalocean_reserved_ip.this[0].ip_address, null)
  description = "Reserved (floating) IP address for static connectivity"
}