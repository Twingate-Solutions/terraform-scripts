# examples/ecs/main.tf

# Data sources for existing VPC and subnets
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "Private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "Public"
  }
}

# AWS Secrets Manager secrets for Twingate tokens
resource "aws_secretsmanager_secret" "twingate_access_token" {
  name                    = "${var.environment}-twingate-access-token"
  description             = "Twingate access token for ECS connector authentication"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(var.common_tags, {
    Name = "${var.environment}-twingate-access-token"
  })
}

resource "aws_secretsmanager_secret_version" "twingate_access_token" {
  secret_id     = aws_secretsmanager_secret.twingate_access_token.id
  secret_string = var.twingate_access_token
}

resource "aws_secretsmanager_secret" "twingate_refresh_token" {
  name                    = "${var.environment}-twingate-refresh-token"
  description             = "Twingate refresh token for ECS connector authentication"
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(var.common_tags, {
    Name = "${var.environment}-twingate-refresh-token"
  })
}

resource "aws_secretsmanager_secret_version" "twingate_refresh_token" {
  secret_id     = aws_secretsmanager_secret.twingate_refresh_token.id
  secret_string = var.twingate_refresh_token
}

# =============================================================================
# ECS TWINGATE CONNECTOR - FARGATE
# =============================================================================

module "twingate_ecs_fargate" {
  source = "../../modules/twingate-ecs"

  name_prefix       = "${var.environment}-twingate-ecs-fargate"
  subnet_ids        = data.aws_subnets.private.ids
  public_subnet_ids = var.create_load_balancer ? data.aws_subnets.public.ids : []

  # ECS cluster configuration
  create_cluster            = var.create_ecs_cluster
  existing_cluster_name     = var.existing_cluster_name
  enable_container_insights = var.enable_container_insights

  # Task configuration
  launch_type     = "FARGATE"
  cpu             = var.fargate_cpu
  memory          = var.fargate_memory
  twingate_image  = var.twingate_image

  # Service configuration
  desired_count                    = var.fargate_desired_count
  deployment_maximum_percent       = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  assign_public_ip                 = var.assign_public_ip

  # Auto scaling
  enable_autoscaling           = var.enable_autoscaling
  autoscaling_min_capacity     = var.autoscaling_min_capacity
  autoscaling_max_capacity     = var.autoscaling_max_capacity
  autoscaling_cpu_target_value = var.autoscaling_cpu_target_value
  autoscaling_memory_target_value = var.autoscaling_memory_target_value

  # Load balancer (optional)
  enable_nlb_deletion_protection = var.enable_nlb_deletion_protection

  # Network configuration
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # Twingate configuration
  twingate_url                        = var.twingate_url
  twingate_access_token_secret_arn    = aws_secretsmanager_secret.twingate_access_token.arn
  twingate_refresh_token_secret_arn   = aws_secretsmanager_secret.twingate_refresh_token.arn
  log_level                          = var.twingate_log_level
  log_analytics                      = var.twingate_log_analytics
  status_reports_v1                  = var.twingate_status_reports_v1

  # Logging
  log_retention_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ecs-spot"
    Environment = var.environment
    Type        = "ecs-fargate-spot"
  })
}

# =============================================================================
# ECS TWINGATE CONNECTOR - EC2 LAUNCH TYPE (Optional)
# =============================================================================

module "twingate_ecs_ec2" {
  count  = var.create_ec2_connector ? 1 : 0
  source = "../../modules/twingate-ecs"

  name_prefix = "${var.environment}-twingate-ecs-ec2"
  subnet_ids  = data.aws_subnets.private.ids

  # Use existing cluster
  create_cluster        = false
  existing_cluster_name = var.create_ecs_cluster ? module.twingate_ecs_fargate.cluster_name : var.existing_cluster_name

  # Task configuration with EC2 launch type
  launch_type     = "EC2"
  cpu             = var.ec2_cpu
  memory          = var.ec2_memory
  twingate_image  = var.twingate_image

  # Service configuration
  desired_count    = var.ec2_desired_count
  assign_public_ip = false  # EC2 launch type doesn't support public IP assignment

  # Auto scaling
  enable_autoscaling           = var.enable_autoscaling
  autoscaling_min_capacity     = var.ec2_autoscaling_min_capacity
  autoscaling_max_capacity     = var.ec2_autoscaling_max_capacity
  autoscaling_cpu_target_value = var.autoscaling_cpu_target_value

  # Network configuration
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # Twingate configuration
  twingate_url                        = var.twingate_url
  twingate_access_token_secret_arn    = aws_secretsmanager_secret.twingate_access_token.arn
  twingate_refresh_token_secret_arn   = aws_secretsmanager_secret.twingate_refresh_token.arn
  log_level                          = var.twingate_log_level
  log_analytics                      = var.twingate_log_analytics
  status_reports_v1                  = var.twingate_status_reports_v1

  # Logging
  log_retention_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ecs-ec2"
    Environment = var.environment
    Type        = "ecs-ec2"
  })
}twingate_log_level
  log_analytics                      = var.twingate_log_analytics
  status_reports_v1                  = var.twingate_status_reports_v1

  # Logging
  log_retention_days = var.log_retention_days

  # IAM
  task_role_policy_statements = var.additional_task_permissions

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ecs-fargate"
    Environment = var.environment
    Type        = "ecs-fargate"
  })
}

# =============================================================================
# ECS TWINGATE CONNECTOR - FARGATE SPOT (Optional)
# =============================================================================

module "twingate_ecs_fargate_spot" {
  count  = var.create_spot_connector ? 1 : 0
  source = "../../modules/twingate-ecs"

  name_prefix = "${var.environment}-twingate-ecs-spot"
  subnet_ids  = data.aws_subnets.private.ids

  # Use existing cluster
  create_cluster        = false
  existing_cluster_name = var.create_ecs_cluster ? module.twingate_ecs_fargate.cluster_name : var.existing_cluster_name

  # Task configuration with Fargate Spot
  launch_type     = "FARGATE"
  cpu             = var.spot_cpu
  memory          = var.spot_memory
  twingate_image  = var.twingate_image

  capacity_provider_strategies = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight           = 100
      base             = var.spot_base_capacity
    }
  ]

  # Service configuration
  desired_count    = var.spot_desired_count
  assign_public_ip = var.assign_public_ip

  # Network configuration
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # Twingate configuration
  twingate_url                        = var.twingate_url
  twingate_access_token_secret_arn    = aws_secretsmanager_secret.twingate_access_token.arn
  twingate_refresh_token_secret_arn   = aws_secretsmanager_secret.twingate_refresh_token.arn
  log_level                          = var.