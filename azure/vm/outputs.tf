output "resource_group_name" {
  description = "Resource group holding every Azure resource in this module"
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "Demo VNet ID"
  value       = azurerm_virtual_network.this.id
}

output "nat_public_ip" {
  description = "Public egress IP of the NAT gateway"
  value       = azurerm_public_ip.nat.ip_address
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_vm_ids" {
  description = "Azure VM IDs running the Connectors"
  value       = azurerm_linux_virtual_machine.connector[*].id
}

output "private_resource_ip" {
  description = "Private IP of the demo resource VM"
  value       = azurerm_network_interface.private_resource.private_ip_address
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
