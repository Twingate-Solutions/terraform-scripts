# modules/twingate-ecs/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_subnet" "selected" {
  count = length(var.subnet_ids)
  id    = var.subnet_ids[count.index]
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected[0].vpc_id
}

# ECS Cluster (optional - can use existing)
resource "aws_ecs_cluster" "twingate" {
  count = var.create_cluster ? 1 : 0
  name  = "${var.name_prefix}-twingate-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

# Security Group for ECS Service
resource "aws_security_group" "twingate_ecs" {
  name_prefix = "${var.name_prefix}-twingate-ecs"
  vpc_id      = data.aws_vpc.selected.id
  description = "Security group for Twingate ECS connector"

  # Outbound internet access for Twingate
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for Twingate"
  }

  egress {
    from_port   = 30000
    to_port     = 31000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Twingate relay ports"
  }

  # Allow access to internal resources
  dynamic "egress" {
    for_each = var.internal_cidr_blocks
    content {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [egress.value]
      description = "Internal network access"
    }
  }

  dynamic "egress" {
    for_each = var.internal_cidr_blocks
    content {
      from_port   = 0
      to_port     = 65535
      protocol    = "udp"
      cidr_blocks = [egress.value]
      description = "Internal network access UDP"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-twingate-ecs-sg"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "twingate_connector" {
  name              = "/ecs/${var.name_prefix}-twingate-connector"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name_prefix = "${var.name_prefix}-twingate-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "${var.name_prefix}-twingate-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Optional: Additional policies for the task role
resource "aws_iam_role_policy" "ecs_task_policy" {
  count = length(var.task_role_policy_statements) > 0 ? 1 : 0
  name  = "${var.name_prefix}-twingate-ecs-task-policy"
  role  = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.task_role_policy_statements
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "twingate_connector" {
  family                   = "${var.name_prefix}-twingate-connector"
  network_mode             = "awsvpc"
  requires_compatibilities = [var.launch_type]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "twingate-connector"
      image = var.twingate_image
      
      essential = true
      
      environment = [
        {
          name  = "TWINGATE_URL"
          value = var.twingate_url
        },
        {
          name  = "TWINGATE_LOG_LEVEL"
          value = tostring(var.log_level)
        },
        {
          name  = "TWINGATE_LOG_ANALYTICS"
          value = tostring(var.log_analytics)
        },
        {
          name  = "TWINGATE_STATUS_REPORTS_V1"
          value = tostring(var.status_reports_v1)
        }
      ]
      
      secrets = [
        {
          name      = "TWINGATE_ACCESS_TOKEN"
          valueFrom = var.twingate_access_token_secret_arn
        },
        {
          name      = "TWINGATE_REFRESH_TOKEN"
          valueFrom = var.twingate_refresh_token_secret_arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.twingate_connector.name
          "awslogs-region"        = data.aws_subnet.selected[0].availability_zone_id != null ? split("", data.aws_subnet.selected[0].availability_zone)[0:length(split("", data.aws_subnet.selected[0].availability_zone)) - 1] : "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      linuxParameters = {
        capabilities = {
          add = ["NET_ADMIN"]
        }
      }
    }
  ])

  tags = var.tags
}

# Network Load Balancer (if public IP is required)
resource "aws_lb" "twingate_nlb" {
  count              = var.assign_public_ip ? 1 : 0
  name               = "${var.name_prefix}-twingate-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_nlb_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-twingate-nlb"
  })
}

# ECS Service
resource "aws_ecs_service" "twingate_connector" {
  name            = "${var.name_prefix}-twingate-connector"
  cluster         = var.create_cluster ? aws_ecs_cluster.twingate[0].id : var.existing_cluster_name
  task_definition = aws_ecs_task_definition.twingate_connector.arn
  desired_count   = var.desired_count
  launch_type     = var.launch_type

  # Capacity provider strategy (for Fargate Spot)
  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategies
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight           = capacity_provider_strategy.value.weight
      base             = lookup(capacity_provider_strategy.value, "base", null)
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.twingate_ecs.id]
    assign_public_ip = var.launch_type == "FARGATE" ? var.assign_public_ip : false
  }

  # Load balancer configuration (if using NLB)
  dynamic "load_balancer" {
    for_each = var.assign_public_ip ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.twingate_nlb[0].arn
      container_name   = "twingate-connector"
      container_port   = 80  # Placeholder port
    }
  }

  # Service discovery (optional)
  dynamic "service_registries" {
    for_each = var.service_discovery_registry_arn != null ? [1] : []
    content {
      registry_arn = var.service_discovery_registry_arn
    }
  }

  # Deployment configuration
  deployment_configuration {
    maximum_percent         = var.deployment_maximum_percent
    minimum_healthy_percent = var.deployment_minimum_healthy_percent
  }

  # Auto Scaling
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]
}

# Target Group for NLB (if using public IP)
resource "aws_lb_target_group" "twingate_nlb" {
  count       = var.assign_public_ip ? 1 : 0
  name        = "${var.name_prefix}-twingate-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-twingate-tg"
  })
}

# NLB Listener
resource "aws_lb_listener" "twingate_nlb" {
  count             = var.assign_public_ip ? 1 : 0
  load_balancer_arn = aws_lb.twingate_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.twingate_nlb[0].arn
  }

  tags = var.tags
}

# Application Auto Scaling Target
resource "aws_appautoscaling_target" "twingate_connector" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${var.create_cluster ? aws_ecs_cluster.twingate[0].name : var.existing_cluster_name}/${aws_ecs_service.twingate_connector.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.tags
}

# Application Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "twingate_connector_cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name_prefix}-twingate-connector-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.twingate_connector[0].resource_id
  scalable_dimension = aws_appautoscaling_target.twingate_connector[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.twingate_connector[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.autoscaling_cpu_target_value
  }
}

# Application Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "twingate_connector_memory" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name_prefix}-twingate-connector-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.twingate_connector[0].resource_id
  scalable_dimension = aws_appautoscaling_target.twingate_connector[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.twingate_connector[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.autoscaling_memory_target_value
  }
}