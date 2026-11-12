##############################################################
#
# ECS Cluster, Logging, IAM
#
##############################################################

data "aws_partition" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-ecs"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = var.aws_log_retention_days
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: pull images, write logs, read Connector tokens from SSM.
# IAM names are account-global: name_prefix lets the module run in several regions
# of one account. IAM caps name_prefix at 38 chars; the suffix here is 15, so
# app_name is truncated to 23.
resource "aws_iam_role" "task_execution" {
  name_prefix        = "${substr(var.app_name, 0, 23)}-ecs-task-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_connector_tokens" {
  statement {
    actions = ["ssm:GetParameters"]
    resources = concat(
      aws_ssm_parameter.connector_access_token[*].arn,
      aws_ssm_parameter.connector_refresh_token[*].arn,
    )
  }
}

resource "aws_iam_role_policy" "read_connector_tokens" {
  name   = "read-twingate-connector-tokens"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.read_connector_tokens.json
}

##############################################################
#
# Twingate Connectors (one Fargate service per Connector)
#
##############################################################

locals {
  connector_subnet_ids = var.aws_connector_subnet_type == "public" ? aws_subnet.public[*].id : aws_subnet.private[*].id
}

# Tokens live in SSM SecureString and are injected as ECS secrets,
# so they do not appear in plaintext in the task definition.
resource "aws_ssm_parameter" "connector_access_token" {
  count = var.tg_connector_count

  name  = "/${var.app_name}/twingate/connector-${count.index + 1}/access-token"
  type  = "SecureString"
  value = twingate_connector_tokens.this[count.index].access_token
}

resource "aws_ssm_parameter" "connector_refresh_token" {
  count = var.tg_connector_count

  name  = "/${var.app_name}/twingate/connector-${count.index + 1}/refresh-token"
  type  = "SecureString"
  value = twingate_connector_tokens.this[count.index].refresh_token
}

resource "aws_security_group" "connector" {
  name        = "${var.app_name}-connector-sg"
  description = "Twingate Connector: no inbound, egress anywhere"
  vpc_id      = aws_vpc.this.id

  # Connectors need outbound only: TCP 443 + 30000-31000 to Twingate, UDP for P2P,
  # plus whatever ports the protected resources use. Allow-all keeps the demo simple.
  egress {
    description = "All egress"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "connector" {
  count = var.tg_connector_count

  family                   = "${var.app_name}-connector-${count.index + 1}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.aws_connector_cpu
  memory                   = var.aws_connector_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "twingate-connector"
      image     = var.tg_connector_image
      essential = true
      environment = [
        { name = "TWINGATE_NETWORK", value = var.tg_network },
        { name = "TWINGATE_LOG_ANALYTICS", value = var.tg_log_analytics_version },
        { name = "TWINGATE_LOG_LEVEL", value = var.tg_log_level },
        { name = "TWINGATE_LABEL_DEPLOYED_BY", value = "terraform-aws-ecs" },
      ]
      secrets = [
        { name = "TWINGATE_ACCESS_TOKEN", valueFrom = aws_ssm_parameter.connector_access_token[count.index].arn },
        { name = "TWINGATE_REFRESH_TOKEN", valueFrom = aws_ssm_parameter.connector_refresh_token[count.index].arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "connector-${count.index + 1}"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "connector" {
  count = var.tg_connector_count

  name            = "${var.app_name}-connector-${count.index + 1}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.connector[count.index].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # A token pair may only be used by one running Connector: stop the old task
  # before starting its replacement instead of overlapping them.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # Tasks read the tokens from SSM only at start, and the task definition references
  # the parameter ARN (unchanged on rotation). Redeploy when this Connector's tokens change.
  force_new_deployment = true
  triggers = {
    connector_tokens = sha256("${twingate_connector_tokens.this[count.index].access_token}${twingate_connector_tokens.this[count.index].refresh_token}")
  }

  network_configuration {
    subnets          = [local.connector_subnet_ids[count.index % length(local.connector_subnet_ids)]]
    security_groups  = [aws_security_group.connector.id]
    assign_public_ip = var.aws_connector_subnet_type == "public"
  }

  depends_on = [
    aws_iam_role_policy.read_connector_tokens,
    aws_iam_role_policy_attachment.task_execution,
    aws_route.private_default,
    aws_route_table_association.private,
  ]
}

##############################################################
#
# Private Resource (nginx on Fargate, registered in Cloud Map)
#
##############################################################

resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.aws_dns_zone_name
  description = "Private DNS for the ${var.app_name} Twingate demo"
  vpc         = aws_vpc.this.id
}

# web-<deployment> keeps Resource addresses unique when several modules share a tenant
resource "aws_service_discovery_service" "private_resource" {
  name = "web-ecs"

  # Deregister leftover task instances so destroy does not fail with ResourceInUse
  force_destroy = true

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_security_group" "private_resource" {
  name        = "${var.app_name}-resource-sg"
  description = "Private resource: inbound from inside the VPC only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "All traffic from the VPC (Connectors)"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    description = "All egress"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "private_resource" {
  family                   = "${var.app_name}-private-resource"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "web"
      image        = "public.ecr.aws/nginx/nginx:stable-alpine"
      essential    = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "private-resource"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "private_resource" {
  name            = "${var.app_name}-private-resource"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.private_resource.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private[0].id]
    security_groups  = [aws_security_group.private_resource.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.private_resource.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution,
    aws_route.private_default,
    aws_route_table_association.private,
  ]
}
