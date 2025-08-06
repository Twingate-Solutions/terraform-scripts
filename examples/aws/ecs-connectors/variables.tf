# examples/ecs/variables.tf

# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

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
    Project   = "twingate-connector"
    ManagedBy = "terraform"
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

variable "assign_public_ip" {
  description = "Whether to assign public IP addresses to Fargate tasks"
  type        = bool
  default     = false
}

variable "create_load_balancer" {
  description = "Whether to create a Network Load Balancer"
  type        = bool
  default     = false
}

variable "enable_nlb_deletion_protection" {
  description = "Whether to enable deletion protection for the NLB"
  type        = bool
  default     = true
}

# =============================================================================
# ECS CLUSTER CONFIGURATION
# =============================================================================

variable "create_ecs_cluster" {
  description = "Whether to create a new ECS cluster"
  type        = bool
  default     = true
}

variable "existing_cluster_name" {
  description = "Name of existing ECS cluster (required if create_ecs_cluster is false)"
  type        = string
  default     = ""
}

variable "enable_container_insights" {
  description = "Whether to enable Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

# =============================================================================
# FARGATE CONFIGURATION
# =============================================================================

variable "twingate_image" {
  description = "Twingate connector Docker image"
  type        = string
  default     = "twingate/connector:latest"
}

variable "fargate_cpu" {
  description = "Number of CPU units for Fargate task"
  type        = number
  default     = 512
}

variable "fargate_memory" {
  description = "Amount of memory in MiB for Fargate task"
  type        = number
  default     = 1024
}

variable "fargate_desired_count" {
  description = "Desired number of Fargate tasks"
  type        = number
  default     = 2
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of tasks that can be running during deployment"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of tasks that must remain healthy during deployment"
  type        = number
  default     = 50
}

# =============================================================================
# FARGATE SPOT CONFIGURATION
# =============================================================================

variable "create_spot_connector" {
  description = "Whether to create a Fargate Spot connector"
  type        = bool
  default     = true
}

variable "spot_cpu" {
  description = "Number of CPU units for Fargate Spot task"
  type        = number
  default     = 256
}

variable "spot_memory" {
  description = "Amount of memory in MiB for Fargate Spot task"
  type        = number
  default     = 512
}

variable "spot_desired_count" {
  description = "Desired number of Fargate Spot tasks"
  type        = number
  default     = 1
}

variable "spot_base_capacity" {
  description = "Base capacity for Fargate Spot"
  type        = number
  default     = 1
}

# =============================================================================
# EC2 LAUNCH TYPE CONFIGURATION
# =============================================================================

variable "create_ec2_connector" {
  description = "Whether to create an EC2 launch type connector"
  type        = bool
  default     = false
}

variable "ec2_cpu" {
  description = "Number of CPU units for EC2 task"
  type        = number
  default     = 512
}

variable "ec2_memory" {
  description = "Amount of memory in MiB for EC2 task"
  type        = number
  default     = 1024
}

variable "ec2_desired_count" {
  description = "Desired number of EC2 tasks"
  type        = number
  default     = 2
}

variable "ec2_autoscaling_min_capacity" {
  description = "Minimum capacity for EC2 auto scaling"
  type        = number
  default     = 1
}

variable "ec2_autoscaling_max_capacity" {
  description = "Maximum capacity for EC2 auto scaling"
  type        = number
  default     = 4
}

# =============================================================================
# AUTO SCALING CONFIGURATION
# =============================================================================

variable "enable_autoscaling" {
  description = "Whether to enable auto scaling for ECS services"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
}

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# =============================================================================
# SECRETS MANAGER CONFIGURATION
# =============================================================================

variable "secret_recovery_window_in_days" {
  description = "Recovery window in days for deleted secrets"
  type        = number
  default     = 7
}

# =============================================================================
# IAM CONFIGURATION
# =============================================================================

variable "additional_task_permissions" {
  description = "Additional IAM policy statements for the ECS task role"
  type        = list(any)
  default     = []
  
  # Example:
  # default = [
  #   {
  #     Effect = "Allow"
  #     Action = [
  #       "s3:GetObject",
  #       "s3:PutObject"
  #     ]
  #     Resource = "arn:aws:s3:::my-bucket/*"
  #   }
  # ]
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
  type        = number
  default     = 4
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