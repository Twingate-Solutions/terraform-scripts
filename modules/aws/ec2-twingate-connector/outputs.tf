# modules/twingate-ec2/outputs.tf

output "security_group_id" {
  description = "ID of the security group created for the Twingate connector"
  value       = aws_security_group.twingate_connector.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role created for the Twingate connector"
  value       = aws_iam_role.twingate_connector.arn
}

output "iam_role_name" {
  description = "Name of the IAM role created for the Twingate connector"
  value       = aws_iam_role.twingate_connector.name
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.twingate_connector.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.twingate_connector.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.twingate_connector.arn
}

output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.assign_public_ip && var.use_elastic_ip ? aws_eip.twingate_connector[0].public_ip : null
}

output "elastic_ip_id" {
  description = "Elastic IP allocation ID (if created)"
  value       = var.assign_public_ip && var.use_elastic_ip ? aws_eip.twingate_connector[0].id : null
}