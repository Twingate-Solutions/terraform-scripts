##############################################################
#
# SSH Key Pair
#
##############################################################

// Add ssh access key => see README.md for instructions
resource "aws_key_pair" "ssh_access_key" {
    key_name        = "${var.app_name}-ssh-key-pair"
    public_key      = file("~/.ssh/aws_id_rsa.pub")
}

##############################################################
#
# Twingate Connector Instance
#
##############################################################

# Pull the id for the latest Twingate AMI 
data "aws_ami" "twingate" {
  most_recent       = true

  filter {
    name            = "name"
    values          = ["twingate/images/hvm-ssd/twingate-amd64-*"]
  }

  owners            = ["617935088040"] # Twingate
}

# Create a new AWS instance, using the latest Twingate AMI from above, to deploy the Connector
# => Public subnet deployment
/*
resource "aws_instance" "twingate_connector" {
    ami             = data.aws_ami.twingate.id
    instance_type   = "t3a.micro"
    associate_public_ip_address = true
    key_name        = aws_key_pair.ssh_access_key.key_name
    subnet_id       = aws_subnet.public.id
    security_groups = [aws_security_group.connector_sg.id]

    user_data       = <<-EOT
    #! /bin/bash
    set -e
    sudo mkdir -p /etc/twingate/
    {
      echo TWINGATE_NETWORK="${var.tg_network}"
      echo TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.tf_demo_aws_connector_tokens.access_token}"
      echo TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.tf_demo_aws_connector_tokens.refresh_token}"
      echo TWINGATE_LOG_ANALYTICS="${var.tg_log_analytics_version}"
      echo TWINGATE_LOG_LEVEL="${var.tg_log_level}"
    } > /etc/twingate/connector.conf
    sudo systemctl enable --now twingate-connector
  EOT

  tags = {
    Name            = twingate_connector.tf_demo_aws_connector.name
    Environment     = var.app_environment
  }
}
*/

# => Private subnet deployment
resource "aws_instance" "twingate_connector" {
    ami             = data.aws_ami.twingate.id
    instance_type   = "t3a.micro"
    key_name        = aws_key_pair.ssh_access_key.key_name
    subnet_id       = aws_subnet.private.id
    security_groups = [aws_security_group.connector_sg.id]
    depends_on      = [aws_nat_gateway.aws-ngw]

    user_data       = <<-EOT
    #! /bin/bash
    set -e
    sudo mkdir -p /etc/twingate/
    {
      echo TWINGATE_NETWORK="${var.tg_network}"
      echo TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.tf_demo_aws_connector_tokens.access_token}"
      echo TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.tf_demo_aws_connector_tokens.refresh_token}"
      echo TWINGATE_LOG_ANALYTICS="${var.tg_log_analytics_version}"
      echo TWINGATE_LOG_LEVEL="${var.tg_log_level}"
    } > /etc/twingate/connector.conf
    sudo systemctl enable --now twingate-connector
  EOT

  tags = {
    Name            = twingate_connector.tf_demo_aws_connector.name
    Environment     = var.app_environment
  }
}

##############################################################
#
# Private Resource Instance
#
##############################################################

# Pull the id for the latest Ubuntu Jammy 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent       = true

  filter {
    name            = "name"
    values          = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name            = "virtualization-type"
    values          = ["hvm"]
  }

  owners            = ["099720109477"] # Canonical
}

# Create a new AWS instance, using the latest Ubuntu AMI from above, to create a private resource
resource "aws_instance" "private_resource" {
    ami             = data.aws_ami.ubuntu.id
    instance_type   = "t2.micro"
    key_name        = aws_key_pair.ssh_access_key.key_name
    subnet_id       = aws_subnet.private.id
    security_groups = [aws_security_group.resource_sg.id]
    depends_on      = [aws_nat_gateway.aws-ngw]
    
    user_data       = <<-EOT
    #! /bin/bash
    sudo apt update
    sudo apt install apache2 -y
    EOT

    tags = {
        Name        = "${var.app_name}-VM"
        Environment = var.app_environment
    }
}