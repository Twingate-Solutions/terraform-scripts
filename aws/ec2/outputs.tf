output "vpc_id" {
  description = "Demo VPC ID"
  value       = aws_vpc.this.id
}

output "nat_public_ip" {
  description = "Public egress IP of the fck-nat instance"
  value       = aws_instance.fck_nat.public_ip
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_instance_ids" {
  description = "EC2 instance IDs running the Connectors"
  value       = aws_instance.twingate_connector[*].id
}

output "private_resource_ip" {
  description = "Private IP of the demo resource instance"
  value       = aws_instance.private_resource.private_ip
}

output "twingate_resource_address" {
  description = "Address to reach through the Twingate Client"
  value       = twingate_resource.private_resource.address
}

output "vpc_peering_connection_id" {
  description = "VPC peering connection ID (null when peering is disabled)"
  value       = one(aws_vpc_peering_connection.peer[*].id)
}

output "service_account_key" {
  description = "Service account key token (null unless tg_create_service_account = true)"
  value       = one(twingate_service_account_key.this[*].token)
  sensitive   = true
}
