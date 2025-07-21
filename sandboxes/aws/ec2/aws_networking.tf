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
  enable_dns_support      = true
  enable_dns_hostnames    = true

  tags = {
    Name                  = "${var.app_name}-vpc"
    Environment           = var.app_environment
  }
}

##############################################################
#
# (Optional) VPC Peering - Connect Demo VPC to Existing VPC
#
##############################################################

# Create a VPC peering connection (optional)
#resource "aws_vpc_peering_connection" "peer" {
#  count            = var.enable_vpc_peering ? 1 : 0
#  vpc_id           = aws_vpc.default.id
#  peer_vpc_id      = var.peer_vpc_id
#  peer_region      = var.peer_region
#  auto_accept      = false

#  tags = {
#    Name        = "${var.app_name}-vpc-peering"
#    Environment = var.app_environment
#  }
#}

# 
resource "aws_vpc_peering_connection" "peer" {
  vpc_id                    = aws_vpc.default.id
  peer_vpc_id               = var.peer_vpc_id
  peer_region               = "us-west-1"           # Adjust if peer is in a different region
  auto_accept               = false
}

# 
resource "aws_vpc_peering_connection_accepter" "peer_accepter" {
  provider                  = aws.us-west-1
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

# 
resource "aws_route" "peer_route_local_to_peer" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "10.50.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# 
resource "aws_route" "peer_route_peer_to_local" {
  provider                 = aws.us-west-1
  route_table_id            = "rtb-04476705007f03223"
  destination_cidr_block    = "10.41.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Update the route table of the local VPC to route traffic to the peer VPC
#resource "aws_route" "peer_route" {
#  count          = var.enable_vpc_peering ? 1 : 0
#  #route_table_id = aws_default_route_table.public.id
#  route_table_id = aws_vpc.default.default_route_table_id
#  destination_cidr_block = "10.50.0.0/16" #var.peer_vpc_cidr_block
#  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
#}

# Update the route table of the peer VPC to route traffic back to the local VPC
#resource "aws_route" "peer_return_route" {
#  count          = var.enable_vpc_peering ? 1 : 0
#  #route_table_id = aws_route_table.private.id # Assuming the peer VPC has a private route table; adjust if needed
#  route_table_id = "rtb-066bd104b34f45954" #aws_vpc.default.default_route_table_id
#  destination_cidr_block = "10.41.0.0/16" #var.aws_vpc_cidr_block
#  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
#}

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
  #gateway_id              = aws_nat_gateway.aws-ngw.id           # Enable if using AWS default NGW
  network_interface_id    = aws_network_interface.fck-nat-if.id   # Enable if using fck-nat gateway
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
# NAT Gateways
#
##############################################################

# Peer-to-Peer Friendly NAT Gateway
data "aws_ami" "fck_nat" {
  filter {
    name   = "name"
    values = ["fck-nat-al2023-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  owners      = ["568608671756"]
  most_recent = true
}

resource "aws_network_interface" "fck-nat-if" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.fck-nat-sg.id]

  source_dest_check = false
}

resource "aws_instance" "fck-nat" {                                                   
  ami           = data.aws_ami.fck_nat.id
  key_name        = var.aws_ssh_key_pair
  instance_type = "t4g.nano"

  network_interface {
    network_interface_id = aws_network_interface.fck-nat-if.id
    device_index         = 0
  }

  tags = {
    Name        = "${var.app_name}-fck-nat"
    Environment = var.app_environment
  }                                                                              
}

# (Optional) AWS Default NAT Gateway - does not support Peer-to-Peer
#resource "aws_nat_gateway" "aws-ngw" {
#  subnet_id               = aws_subnet.public.id
#  allocation_id           = aws_eip.nat_eip.id

#  tags = {
#    Name                  = "${var.app_name}-ngw"
#    Environment           = var.app_environment
#  }
#}

##############################################################
#
# Elastic IPs
#
##############################################################

# Create an EIP for the NAT gateway to use
resource "aws_eip" "nat_eip" {
    domain                = "vpc"
    depends_on            = [aws_internet_gateway.aws-igw]

    tags = {
        Name              = "${var.app_name}-eip"
        Environment       = var.app_environment
  }
}

# Associate EIP to instance
resource "aws_eip_association" "nat_eip_assoc" {
  instance_id             = aws_instance.fck-nat.id
  allocation_id           = aws_eip.nat_eip.id

  depends_on              = [aws_instance.fck-nat]
}

##############################################################
#
# Security Groups
#
##############################################################

# Create security group for fck-nat instance
resource "aws_security_group" "fck-nat-sg" {                                 
  name                    = "${var.app_name}-fck-nat-sg"
  vpc_id                  = aws_vpc.default.id

  ingress {
    protocol              = "-1"
    from_port             = 0
    to_port               = 0
    cidr_blocks           = [aws_subnet.private.cidr_block]
  }

  egress {
    protocol              = "-1"
    from_port             = 0
    to_port               = 0
    cidr_blocks           = ["0.0.0.0/0"]
  }
}

# Create security group for connector
resource "aws_security_group" "connector_sg" {                                 
  name                    = "${var.app_name}-connector-sg"
  vpc_id                  = aws_vpc.default.id

  egress {
    protocol              = "-1"
    from_port             = 0
    to_port               = 0
    cidr_blocks           = ["0.0.0.0/0"]
  }

  # (Optional) Minimum egress rules
  #egress {
  #  protocol              = "tcp"
  #  from_port             = 443
  #  to_port               = 443
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}

  #egress {
  #  protocol              = "tcp"
  #  from_port             = 30000
  #  to_port               = 31000
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}

  #egress {
  #  protocol              = "udp"
  #  from_port             = 0
  #  to_port               = 65535
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}

  # (Optional) The following egress rules are included for the purposes of this demo
  #egress {
  #  protocol              = "icmp"
  #  from_port             = 8
  #  to_port               = 0
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}

  #egress {
  #  protocol              = "tcp"
  #  from_port             = 22
  #  to_port               = 22
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}

  #egress {
  #  protocol              = "tcp"
  #  from_port             = 80
  #  to_port               = 80
  #  cidr_blocks           = ["0.0.0.0/0"]
  #}
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

##############################################################
#
# Route 53 - Private Hosted Zone & DNS
#
##############################################################

# Create the private hosted zone
resource "aws_route53_zone" "private_zone" {
  name = "tg-tf-demo.int"
  vpc {
    vpc_id = aws_vpc.default.id
  }
  comment = "Private hosted zone for tg-tf-demo.int"
}

# Create a DNS record in the private hosted zone
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "tg-tf-demo.int"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.private_resource.private_ip]  # Replace with your private IP address
}

# Output private zone id
output "private_zone_id" {
  value = aws_route53_zone.private_zone.zone_id
}

# Output DNS Record
output "dns_record" {
  value = aws_route53_record.www.fqdn
}

#Using the AWS Management Console:
  #Go to the VPC Dashboard in the AWS Management Console.
  #Select Peering Connections from the left-hand menu.
  #Locate the peering connection that was created by Terraform. It should have a status of Pending Acceptance.
  #Select the connection, then click on Actions and choose Accept Request.
  #Follow the prompts to accept the peering request.