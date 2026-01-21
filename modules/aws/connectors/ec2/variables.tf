# modules/twingate-ec2/variables.tf

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "twingate"
}

variable "subnet_id" {
  description = "Subnet ID where the connector will be deployed"
  type        = string
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the instance"
  type        = bool
  default     = false
}

variable "use_elastic_ip" {
  description = "Whether to use an Elastic IP (only applicable if assign_public_ip is true)"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use for the instance (defaults to latest Amazon Linux 2)"
  type        = string
  default     = null
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "enable_ssh_access" {
  description = "Whether to allow SSH access to the instance"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "internal_cidr_blocks" {
  description = "CIDR blocks for internal network access"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
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

# Auto Scaling Group variables
variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

# EBS variables
variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
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

# Twingate configuration
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

variable "log_level" {
  description = "Log level for Twingate connector (0-7, where 7 is most verbose)"
  type        = string
  default     = "3"
}

variable "log_analytics" {
  description = "Whether to enable log analytics"
  type        = bool
  default     = false
}

variable "status_reports_v1" {
  description = "Whether to enable status reports v1"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}