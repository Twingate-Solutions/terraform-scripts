##############################################################
#
# (Optional) VPC Peering - connect the demo VPC to an existing
# VPC in the same AWS account. Disabled by default.
#
##############################################################

resource "aws_vpc_peering_connection" "peer" {
  count = var.enable_vpc_peering ? 1 : 0

  vpc_id      = aws_vpc.this.id
  peer_vpc_id = var.peer_vpc_id
  peer_region = var.peer_region
  auto_accept = false

  tags = {
    Name = "${var.app_name}-peering"
  }

  lifecycle {
    precondition {
      condition     = var.peer_vpc_id != null && var.peer_vpc_cidr_block != null
      error_message = "enable_vpc_peering requires peer_vpc_id and peer_vpc_cidr_block."
    }
  }
}

# Accept from the peer side (same account; peer region via the aliased provider)
resource "aws_vpc_peering_connection_accepter" "peer" {
  count    = var.enable_vpc_peering ? 1 : 0
  provider = aws.peer

  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
  auto_accept               = true

  tags = {
    Name = "${var.app_name}-peering"
  }
}

# Demo VPC -> peer VPC. Connectors sit in either subnet type
# (aws_connector_subnet_type), so both route tables get the route.
resource "aws_route" "to_peer" {
  count = var.enable_vpc_peering ? 1 : 0

  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = var.peer_vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}

resource "aws_route" "to_peer_public" {
  count = var.enable_vpc_peering ? 1 : 0

  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = var.peer_vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}

# Demo VPC <- peer VPC return route (only when peer_route_table_id is supplied)
resource "aws_route" "from_peer" {
  count    = var.enable_vpc_peering && var.peer_route_table_id != null ? 1 : 0
  provider = aws.peer

  route_table_id            = var.peer_route_table_id
  destination_cidr_block    = aws_vpc.this.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[0].id
}
