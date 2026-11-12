output "vpc_id" {
  description = "Demo VPC ID"
  value       = aws_vpc.this.id
}

output "nat_public_ip" {
  description = "Public egress IP of the fck-nat instance"
  value       = aws_instance.fck_nat.public_ip
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "connector_names" {
  description = "Twingate Connector names"
  value       = twingate_connector.this[*].name
}

output "connector_service_names" {
  description = "ECS service names running the Connectors"
  value       = aws_ecs_service.connector[*].name
}

output "log_group_name" {
  description = "CloudWatch log group for Connector and resource containers"
  value       = aws_cloudwatch_log_group.this.name
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
