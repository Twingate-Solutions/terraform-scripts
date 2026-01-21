# examples/ec2/variables.tf

# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "twingate-connector"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "additional_cidr_blocks" {
  description = "Additional CIDR blocks for internal network access"
  type        = list(string)
  default     = ["172.16.0.0/12", "192.168.0.0/16"]
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access to private instances"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "public_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access to public instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Be more restrictive in production
}

# =============================================================================
# EC2 CONFIGURATION
# =============================================================================

variable "ec2_key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "enable_ssh_access" {
  description = "Whether to allow SSH access to instances"
  type        = bool
  default     = true
}

variable "enable_ssm" {
  description = "Whether to enable AWS Systems Manager access"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

# Private Connector Configuration
variable "ec2_instance_type" {
  description = "Instance type for private EC2 connector"
  type        = string
  default     = "t3.small"
}

variable "ec2_min_size" {
  description = "Minimum number of instances in private ASG"
  type        = number
  default     = 1
}

variable "ec2_max_size" {
  description = "Maximum number of instances in private ASG"
  type        = number
  default     = 3
}

variable "ec2_desired_capacity" {
  description = "Desired number of instances in private ASG"
  type        = number
  default     = 2
}

# Public Connector Configuration (Optional)
variable "create_public_connector" {
  description = "Whether to create a public EC2 connector"
  type        = bool
  default     = false
}

variable "ec2_public_instance_type" {
  description = "Instance type for public EC2 connector"
  type        = string
  default     = "t3.micro"
}

variable "use_elastic_ip" {
  description = "Whether to use Elastic IP for public connector"
  type        = bool
  default     = true
}

# High Availability Connector Configuration (Optional)
variable "create_ha_connector" {
  description = "Whether to create a high availability EC2 connector"
  type        = bool
  default     = false
}

variable "ec2_ha_instance_type" {
  description = "Instance type for HA EC2 connector"
  type        = string
  default     = "t3.medium"
}

variable "ec2_ha_min_size" {
  description = "Minimum number of instances in HA ASG"
  type        = number
  default     = 2
}

variable "ec2_ha_max_size" {
  description = "Maximum number of instances in HA ASG"
  type        = number
  default     = 6
}

variable "ec2_ha_desired_capacity" {
  description = "Desired number of instances in HA ASG"
  type        = number
  default     = 3
}

# =============================================================================
# EBS CONFIGURATION
# =============================================================================

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_size_ha" {
  description = "Size of the root EBS volume in GB for HA instances"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type of the root EBS volume"
  type        = string
  default     = "gp3"
}

variable "encrypt_root_volume" {
  description = "Whether to encrypt the root EBS volume"
  type        = bool
  default     = true
}

# =============================================================================
# TWINGATE CONFIGURATION
# =============================================================================

variable "twingate_url" {
  description = "Twingate tenant URL (e.g., https://mycompany.twingate.com)"
  type        = string
}

variable "twingate_access_token" {
  description = "Twingate access token"
  type        = string
  sensitive   = true
}

variable "twingate_refresh_token" {
  description = "Twingate refresh token"
  type        = string
  sensitive   = true
}

variable "twingate_log_level" {
  description = "Log level for Twingate connector (0-7, where 7 is most verbose)"
  type        = string
  default     = "3"
}

variable "twingate_log_level_ha" {
  description = "Log level for HA Twingate connector"
  type        = string
  default     = "4"
}

variable "twingate_log_analytics" {
  description = "Whether to enable log analytics"
  type        = bool
  default     = true
}

variable "twingate_status_reports_v1" {
  description = "Whether to enable status reports v1"
  type        = bool
  default     = true
}