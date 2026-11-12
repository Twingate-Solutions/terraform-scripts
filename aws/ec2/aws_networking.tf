##############################################################
#
# Shared AWS networking (kept in sync across aws/* modules)
#
# VPC, public/private subnets per AZ, internet gateway, and a
# fck-nat instance as the NAT for private subnets. fck-nat is
# used instead of the AWS managed NAT gateway because it is
# NAT-traversal friendly, which Twingate peer-to-peer needs.
#
##############################################################

# Default-enabled AZs only: Local/Wavelength Zones need an opt-in and lack most instance types
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  az_names = data.aws_availability_zones.available.names

  # min() keeps this evaluable when the region is short of AZs, so the VPC
  # precondition below reports the problem instead of a slice() error
  azs = slice(local.az_names, 0, min(var.aws_az_count, length(local.az_names)))
}

##############################################################
#
# VPC & Subnets
#
##############################################################

resource "aws_vpc" "this" {
  cidr_block           = var.aws_vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.app_name}-vpc"
  }

  lifecycle {
    precondition {
      condition     = length(local.az_names) >= var.aws_az_count
      error_message = "Region ${var.aws_region} has ${length(local.az_names)} available AZ(s) (opt-in zones excluded), fewer than aws_az_count = ${var.aws_az_count}. Lower aws_az_count or choose another region."
    }
  }
}

resource "aws_subnet" "public" {
  count = var.aws_az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = var.aws_az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.app_name}-private-${local.azs[count.index]}"
  }
}

##############################################################
#
# Internet Gateway & Public Routing
#
##############################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.aws_az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

##############################################################
#
# fck-nat (NAT instance) & Private Routing
#
##############################################################

data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"] # fck-nat

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_security_group" "fck_nat" {
  name        = "${var.app_name}-fck-nat-sg"
  description = "fck-nat: accept traffic from private subnets, egress anywhere"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "All traffic from private subnets"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = aws_subnet.private[*].cidr_block
  }

  egress {
    description = "All egress"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "fck_nat" {
  ami                         = data.aws_ami.fck_nat.id
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  source_dest_check           = false
  vpc_security_group_ids      = [aws_security_group.fck_nat.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.app_name}-fck-nat"
  }

  # most_recent AMI would otherwise replace the NAT on every new fck-nat release.
  # Pick up a newer AMI with: terraform apply -replace=aws_instance.fck_nat
  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_route.public_default]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.app_name}-private-rt"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.fck_nat.primary_network_interface_id
}

resource "aws_route_table_association" "private" {
  count = var.aws_az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
