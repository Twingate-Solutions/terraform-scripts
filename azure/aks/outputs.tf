output "resource_group_name" {
  description = "Resource group holding the VNet, NAT gateway and AKS cluster"
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "Demo VNet ID"
  value       = azurerm_virtual_network.this.id
}

output "nat_public_ip" {
  description = "Public egress IP of the NAT gateway (cluster egress)"
  value       = azurerm_public_ip.nat.ip_address
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_get_credentials_command" {
  description = "Command to merge the cluster's kubeconfig locally"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name}"
}

output "kubernetes_namespace" {
  description = "Namespace holding the Connector releases and the demo nginx service"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_release_names" {
  description = "Helm releases running the Connectors"
  value       = helm_release.connector[*].name
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
