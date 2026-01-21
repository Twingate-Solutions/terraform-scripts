
# SSH Keys - Enables secure authentication to droplets without password
resource "digitalocean_ssh_key" "ssh_keys" {
  for_each   = var.ssh_keys
  # Required variables
  name       = coalesce(each.key, each.value.name)
  public_key = each.value.public_key
}

# Droplet (Virtual Machine) - Core compute resource for running Twingate connector
resource "digitalocean_droplet" "main" {
  count              = var.enabled == true ? var.droplet_count : 0
  # Required variables
  image              = var.image_name
  name               = format("%s-droplet-%s", local.labels_id, (count.index))
  region             = var.region
  size               = var.droplet_size
  # Optional variables
  backups            = var.backups
  backup_policy {
    plan             = var.backup_policy_plan
    weekday          = var.backup_policy_weekday
    hour             = var.backup_policy_hour
  }
  monitoring         = var.monitoring
  ipv6               = var.ipv6
  vpc_uuid           = var.vpc_uuid
  private_networking = var.enable_private_networking
  ssh_keys           = local.ssh_key_ids
  resize_disk        = var.resize_disk
  tags               = var.tags
  user_data          = var.user_data
  volume_ids         = var.volume_ids
  droplet_agent      = var.droplet_agent
  graceful_shutdown  = var.graceful_shutdown
}

# Block Storage Volume - Persistent storage for droplet data
resource "digitalocean_volume" "main" {
  count                    = var.enabled == true ? var.droplet_count : 0
  # Required variables
  region                   = var.region
  name                     = format("%s-volume-%s", local.labels_id, (count.index))
  size                     = var.block_storage_size
  # Optional variables
  description              = "Block storage for ${element(digitalocean_droplet.main[*].name, count.index)}"
  snapshot_id              = var.snapshot_id
  initial_filesystem_label = var.block_storage_filesystem_label
  initial_filesystem_type  = var.block_storage_filesystem_type
  tags                     = var.tags
}

# Volume Attachment - Connects block storage volume to droplet
resource "digitalocean_volume_attachment" "main" {
  depends_on = [digitalocean_droplet.main, digitalocean_volume.main]
  count      = var.enabled == true ? var.droplet_count : 0
  # Required variables
  droplet_id = element(digitalocean_droplet.main[*].id, count.index)
  volume_id  = element(digitalocean_volume.main[*].id, count.index)
}

# Floating IP (Reserved IP) - Static IP address for reliable connectivity
resource "digitalocean_reserved_ip" "this" {
  count  = var.floating_ip == true && var.enabled == true ? var.droplet_count : 0
  # Required variables
  region = var.region
  # Optional variables
  droplet_id = 
}

# Floating IP Assignment - Associates reserved IP with droplet
resource "digitalocean_reserved_ip_assignment" "ip_assignment" {
  count      = var.floating_ip == true && var.enabled == true ? var.droplet_count : 0
  depends_on = [digitalocean_droplet.main, digitalocean_reserved_ip.this, digitalocean_volume_attachment.main]
  # Required variables
  ip_address = element(digitalocean_reserved_ip.this[*].ip_address, count.index)
  # Optional variables
  droplet_id = element(digitalocean_droplet.main[*].id, count.index)
}

# Firewall - Controls inbound and outbound network traffic
# For Twingate connectors, default configuration enables:
# - NO inbound rules (connectors initiate outbound connections only)
# - Outbound TCP 443, TCP 30000-31000, UDP 0-65535 - https://help.twingate.com/hc/en-us/articles/14142225907485-Allowlist-for-outbound-connections-to-Twingate-infrastructure
# - All destinations (0.0.0.0/0, ::/0) to reach Twingate's ephemeral infrastructure
resource "digitalocean_firewall" "default" {
  depends_on  = [digitalocean_droplet.main]
  count       = var.enable_firewall == true && var.enabled == true ? 1 : 0
  # Required variables
  name        = format("%s-droplet-firewall", local.labels_id)
  # Optional variables
  droplet_ids = digitalocean_droplet.main[*].id
  tags        = var.tags

  dynamic "inbound_rule" {
    for_each = var.inbound_rules
    content {
      port_range       = inbound_rule.value.allowed_ports
      protocol         = lookup(inbound_rule.value, "protocol", "tcp")
      source_addresses = inbound_rule.value.allowed_ip
    }
  }

  dynamic "outbound_rule" {
    for_each = var.outbound_rule
    content {
      protocol                    = outbound_rule.value.protocol
      port_range                  = outbound_rule.value.port_range
      destination_addresses       = length(outbound_rule.value.destination_addresses) > 0 ? outbound_rule.value.destination_addresses : null
      destination_droplet_ids     = length(outbound_rule.value.destination_droplet_ids) > 0 ? outbound_rule.value.destination_droplet_ids : null
      destination_kubernetes_ids  = length(outbound_rule.value.destination_kubernetes_ids) > 0 ? outbound_rule.value.destination_kubernetes_ids : null
      destination_tags            = length(outbound_rule.value.destination_tags) > 0 ? outbound_rule.value.destination_tags : null
      destination_load_balancer_uids = length(outbound_rule.value.destination_load_balancer_uids) > 0 ? outbound_rule.value.destination_load_balancer_uids : null
    }
  }
}