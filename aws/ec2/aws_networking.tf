##############################################################
#
# Availability Zones
#
##############################################################

# Get a list of available zones for the region
data "aws_availability_zones" "available_zones" {
  state                   = "available"
}

# Output a list of available zones for the region
output "available_zones" {
  value                   = data.aws_availability_zones.available_zones.names
}

# Output the first available zone (to be used as our AZ later)
output "picked_available_zone" {
  value                   = data.aws_availability_zones.available_zones.names[0]
}

##############################################################
#
# VPCs
#
##############################################################

# Create a VPC
resource "aws_vpc" "default" {
  cidr_block              = var.aws_vpc_cidr_block
  tags = {
    Name                  = "${var.app_name}-vpc"
    Environment           = var.app_environment
  }
}

##############################################################
#
# Subnets
#
##############################################################

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, 0)
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                  = "${var.app_name}-public-subnet"
    Environment           = var.app_environment
  }
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, 1)
  availability_zone       = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name                  = "${var.app_name}-private-subnet"
    Environment           = var.app_environment
  }
}

##############################################################
#
# Route Tables
#
##############################################################

# PUBLIC

# Use the default route table created with the VPC as the route table for the public subnet (one is created automatically by default)
resource "aws_default_route_table" "public" {
  default_route_table_id  = aws_vpc.default.default_route_table_id                  

  tags = {
    Name                  = "${var.app_name}-public-route-table"
    Environment           = var.app_environment
  }
}

# Add a route in the "public" route table
resource "aws_route" "public" {
  route_table_id          = aws_default_route_table.public.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.aws-igw.id
}

# Associate the "public" route table to the public subnet
resource "aws_route_table_association" "public" {
  subnet_id               = aws_subnet.public.id
  route_table_id          = aws_default_route_table.public.id
}


# PRIVATE

# Create a new route table for the private subnet
resource "aws_route_table" "private" {
  vpc_id                  = aws_vpc.default.id

  tags = {
    Name                  = "${var.app_name}-private-route-table"
    Environment           = var.app_environment
  }
}

# Add a route in the "private" route table
resource "aws_route" "private" {
  route_table_id          = aws_route_table.private.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_nat_gateway.aws-ngw.id
}

# Associate the "private" route table to the private subnet
resource "aws_route_table_association" "private" {
  subnet_id               = aws_subnet.private.id
  route_table_id          = aws_route_table.private.id
}

##############################################################
#
# Internet Gateways
#
##############################################################

# Create an internet gateway for the public subnet to use
resource "aws_internet_gateway" "aws-igw" {
  vpc_id                  = aws_vpc.default.id

  tags = {
    Name                  = "${var.app_name}-igw"
    Environment           = var.app_environment
  }
}

##############################################################
#
# Elastic IPs
#
##############################################################

# Create an EIP for the NAT gateway to use
resource "aws_eip" "aws_eip" {
    domain                = aws_vpc.default.id
    depends_on            = [aws_internet_gateway.aws-igw]

    tags = {
        Name              = "${var.app_name}-eip"
        Environment       = var.app_environment
  }
}

##############################################################
#
# NAT Gateways
#
##############################################################

# Create a NAT gateway and add it to the public subnet
resource "aws_nat_gateway" "aws-ngw" {
  subnet_id               = aws_subnet.public.id
  allocation_id           = aws_eip.aws_eip.id

  tags = {
    Name                  = "${var.app_name}-ngw"
    Environment           = var.app_environment
  }
}

##############################################################
#
# Security Groups
#
##############################################################

# Create security group for connector
resource "aws_security_group" "connector_sg" {                                 
  name                    = "${var.app_name}-connector-sg"
  vpc_id                  = aws_vpc.default.id

  egress {
    protocol              = "tcp"
    from_port             = 443
    to_port               = 443
    cidr_blocks           = ["0.0.0.0/0"]
  }

  egress {
    protocol              = "tcp"
    from_port             = 30000
    to_port               = 31000
    cidr_blocks           = ["0.0.0.0/0"]
  }

  egress {
    protocol              = "udp"
    from_port             = 0
    to_port               = 65535
    cidr_blocks           = ["0.0.0.0/0"]
  }

  # the following egress rules are included for the purposes of this demo
  egress {
    protocol              = "icmp"
    from_port             = 8
    to_port               = 0
    cidr_blocks           = ["0.0.0.0/0"]
  }

  egress {
    protocol              = "tcp"
    from_port             = 22
    to_port               = 22
    cidr_blocks           = ["0.0.0.0/0"]
  }

  egress {
    protocol              = "tcp"
    from_port             = 80
    to_port               = 80
    cidr_blocks           = ["0.0.0.0/0"]
  }
}

# Create security group for private resource
resource "aws_security_group" "resource_sg" {                                 
  name                    = "${var.app_name}-resource-sg"
  vpc_id                  = aws_vpc.default.id

  ingress {
    protocol              = "-1"
    from_port             = 0
    to_port               = 0
    cidr_blocks           = ["0.0.0.0/0"]
  }

  egress {
    protocol              = "-1"
    from_port             = 0
    to_port               = 0
    cidr_blocks           = ["0.0.0.0/0"]
  }
}
