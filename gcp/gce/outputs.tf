output "vpc_id" {
  description = "Demo VPC network ID"
  value       = google_compute_network.this.id
}

output "nat_public_ip" {
  description = "Static Cloud NAT egress IP"
  value       = google_compute_address.nat.address
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_instance_names" {
  description = "GCE instance names running the Connectors"
  value       = google_compute_instance.connector[*].name
}

output "connector_instance_zones" {
  description = "Zones of the Connector instances"
  value       = google_compute_instance.connector[*].zone
}

output "private_resource_ip" {
  description = "Private IP of the demo resource instance"
  value       = google_compute_instance.private_resource.network_interface[0].network_ip
}

output "twingate_resource_address" {
  description = "Address to reach through the Twingate Client"
  value       = twingate_resource.private_resource.address
}

output "service_account_key" {
  description = "Service account key token (null unless tg_create_service_account = true)"
  value       = one(twingate_service_account_key.this[*].token)
  sensitive   = true
}
