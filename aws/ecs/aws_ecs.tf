##############################################################
#
# ECS Cluster
#
##############################################################

# Create an ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-ecs-cluster"
}

##############################################################
#
# ECS Task Definitions
#
##############################################################

// Create an ECS Task Definition for the Twingate Connectors (2)
resource "aws_ecs_task_definition" "twingate_connectors" {
  family                   = "${var.app_name}-twingate-connector"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  #execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  cpu                      = 2048
  memory                   = 4096

  container_definitions = jsonencode([
    {
      #name  = "${var.app_name}-ecs-connector-1"
      name  = twingate_connector.connector_1.name
      image = "twingate/connector:1"
      essential = true
      cpu       = 1024
      memory    = 2048
      environment = [
        {
          name  = "TWINGATE_NETWORK"
          value = var.tg_network
        },
        {
          name  = "TWINGATE_ACCESS_TOKEN"
          value = twingate_connector_tokens.connector_1_tokens.access_token
        },
        {
          name  = "TWINGATE_REFRESH_TOKEN"
          value = twingate_connector_tokens.connector_1_tokens.refresh_token
        },
        {
          name  = "TWINGATE_LOG_ANALYTICS"
          value = var.tg_log_analytics_version
        },
        {
          name  = "TWINGATE_LOG_LEVEL"
          value = var.tg_log_level
        }
      ]
    },
    {
      #name  = "${var.app_name}-ecs-connector-2"
      name  = twingate_connector.connector_2.name
      image = "twingate/connector:1"
      essential = true
      cpu       = 1024
      memory    = 2048
      environment = [
        {
          name  = "TWINGATE_NETWORK"
          value = var.tg_network
        },
        {
          name  = "TWINGATE_ACCESS_TOKEN"
          value = twingate_connector_tokens.connector_2_tokens.access_token
        },
        {
          name  = "TWINGATE_REFRESH_TOKEN"
          value = twingate_connector_tokens.connector_2_tokens.refresh_token
        },
        {
          name  = "TWINGATE_LOG_ANALYTICS"
          value = var.tg_log_analytics_version
        },
        {
          name  = "TWINGATE_LOG_LEVEL"
          value = var.tg_log_level
        }
      ]
    },
  ])
}

// Create an ECS Task Definition for an example private resource
resource "aws_ecs_task_definition" "private_resource" {
  family                   = "${var.app_name}-private-resource"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  #execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name  = "private-resource"
      image = "dockersamples/static-site"
      essential = true
    }
  ])
}

##############################################################
#
# ECS Services
#
##############################################################

resource "aws_ecs_service" "twingate_connectors" {
  name            = "${var.app_name}-twingate-connector-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.twingate_connectors.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]                  # change to public if needed
    security_groups  = [aws_security_group.connector_sg.id]
    assign_public_ip = false                                    # set to true if public is needed
  }
}

resource "aws_ecs_service" "private_resource" {
  name            = "${var.app_name}-private-resource-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.private_resource.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_ecs_managed_tags = true

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.resource_sg.id]
    assign_public_ip = false
  }

  tags = {
    "Name" = "${var.app_name}-private-resource-service"
  }
}

##############################################################
#
# Grab the private IP of the private resource
#
##############################################################

# Retrieve a list of network interfaces with a matching tag to the private resource service
data "aws_network_interfaces" "private_resource" {
  depends_on = [ aws_ecs_service.private_resource ]
  filter {
    name   = "tag:aws:ecs:clusterName"
    values = [aws_ecs_cluster.main.name] 
  }

  filter {
    name   = "tag:aws:ecs:serviceName"
    values = [aws_ecs_service.private_resource.name]
  }
}
# Output ENI id [0]
output "aws_network_interfaces" {
  value = data.aws_network_interfaces.private_resource.ids[0]
}

# Retrieve information about [0]th ENI
data "aws_network_interface" "private_resource" {
  depends_on = [ aws_ecs_service.private_resource, data.aws_network_interfaces.private_resource ]
  id = data.aws_network_interfaces.private_resource.ids[0]
}

# Output private ip for [0]th ENI
output "aws_network_interface_private_resource_ip" {
  value = data.aws_network_interface.private_resource.private_ip
}