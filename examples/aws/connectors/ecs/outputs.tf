# examples/ecs/outputs.tf

# =============================================================================
# FARGATE CONNECTOR OUTPUTS
# =============================================================================

output "fargate_connector" {
  description = "ECS Fargate connector information"
  value = {
    name                    = "${var.environment}-twingate-ecs-fargate"
    cluster_id              = module.twingate_ecs_fargate.cluster_id
    cluster_name            = module.twingate_ecs_fargate.cluster_name
    cluster_arn             = module.twingate_ecs_fargate.cluster_arn
    service_name            = module.twingate_ecs_fargate.service_name
    service_arn             = module.twingate_ecs_fargate.service_arn
    task_definition_arn     = module.twingate_ecs_fargate.task_definition_arn
    security_group_id       = module.twingate_ecs_fargate.security_group_id
    task_execution_role_arn = module.twingate_ecs_fargate.task_execution_role_arn
    task_role_arn           = module.twingate_ecs_fargate.task_role_arn
    log_group_name          = module.twingate_ecs_fargate.cloudwatch_log_group_name
    load_balancer_dns_name  = module.twingate_ecs_fargate.load_balancer_dns_name
    load_balancer_zone_id   = module.twingate_ecs_fargate.load_balancer_zone_id
    autoscaling_target_id   = module.twingate_ecs_fargate.autoscaling_target_resource_id
  }
}

# =============================================================================
# FARGATE SPOT CONNECTOR OUTPUTS (If Created)
# =============================================================================

output "fargate_spot_connector" {
  description = "ECS Fargate Spot connector information"
  value = var.create_spot_connector ? {
    name                    = "${var.environment}-twingate-ecs-spot"
    cluster_name            = module.twingate_ecs_fargate_spot[0].cluster_name
    service_name            = module.twingate_ecs_fargate_spot[0].service_name
    service_arn             = module.twingate_ecs_fargate_spot[0].service_arn
    task_definition_arn     = module.twingate_ecs_fargate_spot[0].task_definition_arn
    security_group_id       = module.twingate_ecs_fargate_spot[0].security_group_id
    task_execution_role_arn = module.twingate_ecs_fargate_spot[0].task_execution_role_arn
    task_role_arn           = module.twingate_ecs_fargate_spot[0].task_role_arn
    log_group_name          = module.twingate_ecs_fargate_spot[0].cloudwatch_log_group_name
  } : null
}

# =============================================================================
# EC2 CONNECTOR OUTPUTS (If Created)
# =============================================================================

output "ec2_connector" {
  description = "ECS EC2 connector information"
  value = var.create_ec2_connector ? {
    name                    = "${var.environment}-twingate-ecs-ec2"
    cluster_name            = module.twingate_ecs_ec2[0].cluster_name
    service_name            = module.twingate_ecs_ec2[0].service_name
    service_arn             = module.twingate_ecs_ec2[0].service_arn
    task_definition_arn     = module.twingate_ecs_ec2[0].task_definition_arn
    security_group_id       = module.twingate_ecs_ec2[0].security_group_id
    task_execution_role_arn = module.twingate_ecs_ec2[0].task_execution_role_arn
    task_role_arn           = module.twingate_ecs_ec2[0].task_role_arn
    log_group_name          = module.twingate_ecs_ec2[0].cloudwatch_log_group_name
    autoscaling_target_id   = module.twingate_ecs_ec2[0].autoscaling_target_resource_id
  } : null
}

# =============================================================================
# SECRETS MANAGER OUTPUTS
# =============================================================================

output "secrets_manager" {
  description = "Secrets Manager information"
  value = {
    access_token = {
      arn  = aws_secretsmanager_secret.twingate_access_token.arn
      name = aws_secretsmanager_secret.twingate_access_token.name
    }
    refresh_token = {
      arn  = aws_secretsmanager_secret.twingate_refresh_token.arn
      name = aws_secretsmanager_secret.twingate_refresh_token.name
    }
  }
}

# =============================================================================
# SECURITY GROUP IDS (For Reference)
# =============================================================================

output "security_group_ids" {
  description = "All security group IDs created by the modules"
  value = compact([
    module.twingate_ecs_fargate.security_group_id,
    var.create_spot_connector ? module.twingate_ecs_fargate_spot[0].security_group_id : "",
    var.create_ec2_connector ? module.twingate_ecs_ec2[0].security_group_id : ""
  ])
}

# =============================================================================
# IAM ROLE ARNS (For Reference)
# =============================================================================

output "task_execution_role_arns" {
  description = "All ECS task execution role ARNs"
  value = compact([
    module.twingate_ecs_fargate.task_execution_role_arn,
    var.create_spot_connector ? module.twingate_ecs_fargate_spot[0].task_execution_role_arn : "",
    var.create_ec2_connector ? module.twingate_ecs_ec2[0].task_execution_role_arn : ""
  ])
}

output "task_role_arns" {
  description = "All ECS task role ARNs"
  value = compact([
    module.twingate_ecs_fargate.task_role_arn,
    var.create_spot_connector ? module.twingate_ecs_fargate_spot[0].task_role_arn : "",
    var.create_ec2_connector ? module.twingate_ecs_ec2[0].task_role_arn : ""
  ])
}

# =============================================================================
# CLOUDWATCH LOG GROUPS (For Reference)
# =============================================================================

output "log_group_names" {
  description = "All CloudWatch log group names"
  value = compact([
    module.twingate_ecs_fargate.cloudwatch_log_group_name,
    var.create_spot_connector ? module.twingate_ecs_fargate_spot[0].cloudwatch_log_group_name : "",
    var.create_ec2_connector ? module.twingate_ecs_ec2[0].cloudwatch_log_group_name : ""
  ])
}

# =============================================================================
# SUMMARY OUTPUT
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployed ECS connectors"
  value = {
    environment = var.environment
    cluster = {
      created = var.create_ecs_cluster
      name    = var.create_ecs_cluster ? module.twingate_ecs_fargate.cluster_name : var.existing_cluster_name
    }
    connectors = {
      fargate_connector = {
        deployed      = true
        launch_type   = "FARGATE"
        desired_count = var.fargate_desired_count
        cpu           = var.fargate_cpu
        memory        = var.fargate_memory
      }
      fargate_spot_connector = {
        deployed      = var.create_spot_connector
        launch_type   = "FARGATE_SPOT"
        desired_count = var.create_spot_connector ? var.spot_desired_count : 0
        cpu           = var.create_spot_connector ? var.spot_cpu : 0
        memory        = var.create_spot_connector ? var.spot_memory : 0
      }
      ec2_connector = {
        deployed      = var.create_ec2_connector
        launch_type   = "EC2"
        desired_count = var.create_ec2_connector ? var.ec2_desired_count : 0
        cpu           = var.create_ec2_connector ? var.ec2_cpu : 0
        memory        = var.create_ec2_connector ? var.ec2_memory : 0
      }
    }
    total_connectors = 1 + (var.create_spot_connector ? 1 : 0) + (var.create_ec2_connector ? 1 : 0)
    features = {
      autoscaling       = var.enable_autoscaling
      container_insights = var.enable_container_insights
      load_balancer     = var.create_load_balancer
    }
  }
}