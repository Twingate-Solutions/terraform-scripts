# modules/twingate-ec2/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected.vpc_id
}

# Security Group
resource "aws_security_group" "twingate_connector" {
  name_prefix = "${var.name_prefix}-twingate-connector"
  vpc_id      = data.aws_vpc.selected.id
  description = "Security group for Twingate connector"

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

  # SSH access if enabled
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
      description = "SSH access"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-twingate-connector-sg"
  })
}

# IAM Role for EC2 instance
resource "aws_iam_role" "twingate_connector" {
  name_prefix = "${var.name_prefix}-twingate-connector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "twingate_connector" {
  name_prefix = "${var.name_prefix}-twingate-connector"
  role        = aws_iam_role.twingate_connector.name

  tags = var.tags
}

# Optional: Attach SSM policy for management
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count      = var.enable_ssm ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.twingate_connector.name
}

# User data script
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    twingate_url           = var.twingate_url
    twingate_access_token  = var.twingate_access_token
    twingate_refresh_token = var.twingate_refresh_token
    log_level             = var.log_level
    log_analytics         = var.log_analytics
    status_reports_v1     = var.status_reports_v1
  }))
}

# Launch Template
resource "aws_launch_template" "twingate_connector" {
  name_prefix   = "${var.name_prefix}-twingate-connector"
  image_id      = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.twingate_connector.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.twingate_connector.name
  }

  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type          = var.root_volume_type
      encrypted            = var.encrypt_root_volume
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-twingate-connector"
    })
  }

  tags = var.tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "twingate_connector" {
  name                = "${var.name_prefix}-twingate-connector-asg"
  vpc_zone_identifier = [var.subnet_id]
  target_group_arns   = []
  health_check_type   = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.twingate_connector.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-twingate-connector"
    propagate_at_launch = true
  }
}

# Elastic IP if public IP is requested and we're in a public subnet
resource "aws_eip" "twingate_connector" {
  count  = var.assign_public_ip && var.use_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-twingate-connector-eip"
  })
}

# EIP Association (would need to be handled via user data or external process for ASG)
# Note: For production use, consider using a Network Load Balancer for static IP