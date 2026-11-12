##############################################################
#
# Shared GCP networking (kept in sync across gcp/* modules)
#
# Custom-mode VPC, a private subnet, Cloud Router + Cloud NAT,
# and an ingress rule for traffic from inside the VPC. Cloud
# NAT runs with endpoint-independent mapping, which Twingate
# peer-to-peer needs to traverse the NAT.
#
##############################################################

data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

locals {
  zones = slice(data.google_compute_zones.available.names, 0, var.gcp_zone_count)
}

##############################################################
#
# VPC & Subnet
#
##############################################################

resource "google_compute_network" "this" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Regional subnet: spans every zone in var.gcp_region. No VM in it gets an external IP.
resource "google_compute_subnetwork" "private" {
  name                     = "${local.name_prefix}-private"
  region                   = var.gcp_region
  network                  = google_compute_network.this.id
  ip_cidr_range            = cidrsubnet(var.gcp_vpc_cidr_block, 8, 10)
  private_ip_google_access = true
}

##############################################################
#
# Cloud Router & Cloud NAT
#
##############################################################

resource "google_compute_router" "this" {
  name    = "${local.name_prefix}-router"
  region  = var.gcp_region
  network = google_compute_network.this.id
}

# Static egress IP: stable for allowlisting and exposed as an output
resource "google_compute_address" "nat" {
  name   = "${local.name_prefix}-nat"
  region = var.gcp_region
  labels = local.common_labels
}

resource "google_compute_router_nat" "this" {
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.this.name
  region                             = google_compute_router.this.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Endpoint-independent mapping keeps one public ip:port per internal ip:port regardless
  # of destination, so Twingate P2P hole punching works. Cloud NAT only allows EIM with
  # static port allocation, so dynamic port allocation must stay off.
  enable_endpoint_independent_mapping = true
  enable_dynamic_port_allocation      = false
  min_ports_per_vm                    = var.gcp_nat_min_ports_per_vm

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

##############################################################
#
# Firewall
#
##############################################################

# Connectors need no inbound rules (outbound only). This lets Connectors reach the
# demo resources; nothing outside the VPC address plan is allowed in.
resource "google_compute_firewall" "allow_internal" {
  name          = "${local.name_prefix}-allow-internal"
  description   = "All traffic from inside the ${local.name_prefix} VPC address plan"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  source_ranges = [var.gcp_vpc_cidr_block]

  allow {
    protocol = "all"
  }
}
