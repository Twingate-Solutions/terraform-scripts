##############################################################
#
# Twingate Connector Instances
#
##############################################################

# Latest Twingate Connector AMI
data "aws_ami" "twingate" {
  most_recent = true
  owners      = ["617935088040"] # Twingate

  filter {
    name   = "name"
    values = ["twingate/images/hvm-ssd/twingate-amd64-*"]
  }
}

locals {
  connector_subnet_ids = var.aws_connector_subnet_type == "public" ? aws_subnet.public[*].id : aws_subnet.private[*].id
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

# One instance per Connector, spread across subnets/AZs
resource "aws_instance" "twingate_connector" {
  count = var.tg_connector_count

  ami                         = data.aws_ami.twingate.id
  instance_type               = var.aws_connector_instance_type
  key_name                    = var.aws_ssh_key_pair
  subnet_id                   = local.connector_subnet_ids[count.index % length(local.connector_subnet_ids)]
  associate_public_ip_address = var.aws_connector_subnet_type == "public"
  vpc_security_group_ids      = [aws_security_group.connector.id]
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    set -e
    mkdir -p /etc/twingate/
    {
      echo TWINGATE_NETWORK="${var.tg_network}"
      echo TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.this[count.index].access_token}"
      echo TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.this[count.index].refresh_token}"
      echo TWINGATE_LOG_ANALYTICS="${var.tg_log_analytics_version}"
      echo TWINGATE_LOG_LEVEL="${var.tg_log_level}"
      echo TWINGATE_LABEL_DEPLOYED_BY="terraform-aws-ec2"
    } > /etc/twingate/connector.conf
    systemctl enable --now twingate-connector
  EOT

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.app_name}-${twingate_connector.this[count.index].name}"
  }

  # most_recent AMI would otherwise replace every Connector on each new Twingate AMI.
  # Pick up a newer AMI with: terraform apply -replace='aws_instance.twingate_connector[0]'
  lifecycle {
    ignore_changes = [ami]
  }

  # Private-subnet Connectors need the NAT route in place before first boot
  depends_on = [aws_route.private_default, aws_route_table_association.private]
}

##############################################################
#
# Private Resource Instance (Apache on Ubuntu 26.04 LTS)
#
##############################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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

resource "aws_instance" "private_resource" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.aws_ssh_key_pair
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private_resource.id]

  # First boot can race the fck-nat instance coming up and unattended-upgrades
  # holding the dpkg lock, so retry instead of failing once.
  user_data = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    for attempt in $(seq 1 10); do
      apt-get -o DPkg::Lock::Timeout=300 update &&
        apt-get -o DPkg::Lock::Timeout=300 install -y apache2 && break
      echo "apache2 install attempt $attempt failed; retrying in 30s"
      sleep 30
    done
  EOT

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.app_name}-private-resource"
  }

  # most_recent AMI would otherwise replace the instance on each new Ubuntu build.
  # Pick up a newer AMI with: terraform apply -replace=aws_instance.private_resource
  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_route.private_default, aws_route_table_association.private]
}

##############################################################
#
# Route 53 Private Hosted Zone (FQDN for the private resource)
#
##############################################################

resource "aws_route53_zone" "private" {
  name    = var.aws_dns_zone_name
  comment = "Private hosted zone for the ${var.app_name} Twingate demo"

  vpc {
    vpc_id = aws_vpc.this.id
  }
}

# web-<deployment> keeps Resource addresses unique when several modules share a tenant
resource "aws_route53_record" "private_resource" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "web-ec2.${var.aws_dns_zone_name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.private_resource.private_ip]
}
