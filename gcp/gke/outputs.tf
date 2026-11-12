output "vpc_id" {
  description = "Demo VPC network ID"
  value       = google_compute_network.this.id
}

output "nat_public_ip" {
  description = "Static Cloud NAT egress IP"
  value       = google_compute_address.nat.address
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "gke_get_credentials_command" {
  description = "Command to configure kubectl for the cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${google_container_cluster.this.location} --project ${var.gcp_project_id}"
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_release_names" {
  description = "Helm releases running the Connectors"
  value       = helm_release.connector[*].name
}

output "kubernetes_namespace" {
  description = "Namespace holding the Connectors and the demo Service"
  value       = kubernetes_namespace_v1.this.metadata[0].name
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
