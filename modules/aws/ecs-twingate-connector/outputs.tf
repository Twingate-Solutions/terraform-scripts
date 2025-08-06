# modules/twingate-ecs/outputs.tf

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = var.create_cluster ? aws_ecs_cluster.twingate[0].id : null
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.create_cluster ? aws_ecs_cluster.twingate[0].name : var.existing_cluster_name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = var.create_cluster ? aws_ecs_cluster.twingate[0].arn : null
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.twingate_connector.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.twingate_connector.id
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.twingate_connector.arn
}

output "security_group_id" {
  description = "ID of the security group created for the ECS service"
  value       = aws_security_group.twingate_ecs.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.twingate_connector.name
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer (if created)"
  value       = var.assign_public_ip ? aws_lb.twingate_nlb[0].dns_name : null
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer (if created)"
  value       = var.assign_public_ip ? aws_lb.twingate_nlb[0].zone_id : null
}

output "autoscaling_target_resource_id" {
  description = "Resource ID of the autoscaling target (if enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.twingate_connector[0].resource_id : null
}