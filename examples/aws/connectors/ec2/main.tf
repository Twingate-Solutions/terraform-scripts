# examples/ec2/main.tf

# Data sources for existing VPC and subnets
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "Private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "Public"
  }
}

# =============================================================================
# EC2 TWINGATE CONNECTOR - PRIVATE SUBNET
# =============================================================================

module "twingate_ec2_private" {
  source = "../../modules/twingate-ec2"

  name_prefix = "${var.environment}-twingate-ec2-private"
  subnet_id   = data.aws_subnets.private.ids[0]

  # Instance configuration
  instance_type              = var.ec2_instance_type
  key_pair_name             = var.ec2_key_pair_name
  enable_ssh_access         = var.enable_ssh_access
  ssh_cidr_blocks           = var.ssh_cidr_blocks
  enable_ssm                = var.enable_ssm
  enable_detailed_monitoring = var.enable_detailed_monitoring

  # Auto Scaling Group
  min_size         = var.ec2_min_size
  max_size         = var.ec2_max_size
  desired_capacity = var.ec2_desired_capacity

  # Network configuration
  assign_public_ip = false  # Private subnet, uses NAT gateway
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # EBS configuration
  root_volume_size     = var.root_volume_size
  root_volume_type     = var.root_volume_type
  encrypt_root_volume  = var.encrypt_root_volume

  # Twingate configuration
  twingate_url           = var.twingate_url
  twingate_access_token  = var.twingate_access_token
  twingate_refresh_token = var.twingate_refresh_token
  log_level             = var.twingate_log_level
  log_analytics         = var.twingate_log_analytics
  status_reports_v1     = var.twingate_status_reports_v1

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ec2-private"
    Environment = var.environment
    Type        = "ec2-private"
  })
}

# =============================================================================
# EC2 TWINGATE CONNECTOR - PUBLIC SUBNET (Optional)
# =============================================================================

module "twingate_ec2_public" {
  count  = var.create_public_connector ? 1 : 0
  source = "../../modules/twingate-ec2"

  name_prefix = "${var.environment}-twingate-ec2-public"
  subnet_id   = data.aws_subnets.public.ids[0]

  # Instance configuration
  instance_type     = var.ec2_public_instance_type
  key_pair_name    = var.ec2_key_pair_name
  enable_ssh_access = var.enable_ssh_access
  ssh_cidr_blocks  = var.public_ssh_cidr_blocks
  enable_ssm       = var.enable_ssm

  # Auto Scaling Group
  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  # Network configuration
  assign_public_ip = true
  use_elastic_ip   = var.use_elastic_ip
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # EBS configuration
  root_volume_size     = var.root_volume_size
  root_volume_type     = var.root_volume_type
  encrypt_root_volume  = var.encrypt_root_volume

  # Twingate configuration
  twingate_url           = var.twingate_url
  twingate_access_token  = var.twingate_access_token
  twingate_refresh_token = var.twingate_refresh_token
  log_level             = var.twingate_log_level
  log_analytics         = var.twingate_log_analytics
  status_reports_v1     = var.twingate_status_reports_v1

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ec2-public"
    Environment = var.environment
    Type        = "ec2-public"
  })
}

# =============================================================================
# HIGH AVAILABILITY EC2 CONNECTOR (Optional)
# =============================================================================

module "twingate_ec2_ha" {
  count  = var.create_ha_connector ? 1 : 0
  source = "../../modules/twingate-ec2"

  name_prefix = "${var.environment}-twingate-ec2-ha"
  subnet_id   = data.aws_subnets.private.ids[1] # Use different AZ

  # Instance configuration - larger for HA
  instance_type              = var.ec2_ha_instance_type
  key_pair_name             = var.ec2_key_pair_name
  enable_ssh_access         = var.enable_ssh_access
  ssh_cidr_blocks           = var.ssh_cidr_blocks
  enable_ssm                = var.enable_ssm
  enable_detailed_monitoring = true

  # Auto Scaling Group - HA configuration
  min_size         = var.ec2_ha_min_size
  max_size         = var.ec2_ha_max_size
  desired_capacity = var.ec2_ha_desired_capacity

  # Network configuration
  assign_public_ip = false
  internal_cidr_blocks = concat(
    [data.aws_vpc.main.cidr_block],
    var.additional_cidr_blocks
  )

  # EBS configuration
  root_volume_size     = var.root_volume_size_ha
  root_volume_type     = var.root_volume_type
  encrypt_root_volume  = var.encrypt_root_volume

  # Twingate configuration
  twingate_url           = var.twingate_url
  twingate_access_token  = var.twingate_access_token
  twingate_refresh_token = var.twingate_refresh_token
  log_level             = var.twingate_log_level_ha
  log_analytics         = var.twingate_log_analytics
  status_reports_v1     = var.twingate_status_reports_v1

  tags = merge(var.common_tags, {
    Name        = "${var.environment}-twingate-ec2-ha"
    Environment = var.environment
    Type        = "ec2-ha"
    Tier        = "high-availability"
  })
}