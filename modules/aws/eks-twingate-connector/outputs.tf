# modules/twingate-eks/outputs.tf

output "namespace" {
  description = "Kubernetes namespace where Twingate connector is deployed"
  value       = var.namespace
}

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = kubernetes_deployment.twingate_connector.metadata[0].name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account.twingate_connector.metadata[0].name
}

output "secret_name" {
  description = "Name of the Kubernetes secret containing Twingate credentials"
  value       = kubernetes_secret.twingate_credentials.metadata[0].name
}

output "config_map_name" {
  description = "Name of the Kubernetes config map containing Twingate configuration"
  value       = kubernetes_config_map.twingate_config.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes service (if created)"
  value       = var.create_service ? kubernetes_service.twingate_connector[0].metadata[0].name : null
}

output "hpa_name" {
  description = "Name of the Horizontal Pod Autoscaler (if enabled)"
  value       = var.enable_hpa ? kubernetes_horizontal_pod_autoscaler_v2.twingate_connector[0].metadata[0].name : null
}

output "pdb_name" {
  description = "Name of the Pod Disruption Budget (if enabled)"
  value       = var.enable_pdb ? kubernetes_pod_disruption_budget_v1.twingate_connector[0].metadata[0].name : null
}

output "network_policy_name" {
  description = "Name of the Network Policy (if enabled)"
  value       = var.enable_network_policy ? kubernetes_network_policy.twingate_connector[0].metadata[0].name : null
}

output "labels" {
  description = "Labels applied to the Twingate connector resources"
  value = merge(var.labels, {
    "app.kubernetes.io/name"     = "twingate-connector"
    "app.kubernetes.io/instance" = var.name_prefix
  })
}