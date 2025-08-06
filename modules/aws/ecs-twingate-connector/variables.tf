# modules/twingate-ecs/variables.tf

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "twingate"
}

variable "subnet_ids" {
  description = "List of subnet IDs where the ECS service will be deployed"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the load balancer (required if assign_public_ip is true)"
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Whether to assign public IP addresses to the tasks (requires public subnets or NAT gateway)"
  type        = bool
  default     = false
}

variable "internal_cidr_blocks" {
  description = "CIDR blocks for internal network access"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

# ECS Cluster
variable "create_cluster" {
  description = "Whether to create a new ECS cluster"
  type        = bool
  default     = true
}

variable "existing_cluster_name" {
  description = "Name of existing ECS cluster (required if create_cluster is false)"
  type        = string
  default     = ""
}

variable "enable_container_insights" {
  description = "Whether to enable Container Insights for the ECS cluster"
  type        = bool
  default     = false
}

# ECS Task Configuration
variable "launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"
  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "Launch type must be either FARGATE or EC2."
  }
}

variable "cpu" {
  description = "Number of CPU units for the task (Fargate: 256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Amount of memory in MiB for the task"
  type        = number
  default     = 512
}

variable "twingate_image" {
  description = "Twingate connector Docker image"
  type        = string
  default     = "twingate/connector:latest"
}

# ECS Service Configuration
variable "desired_count" {
  description = "Desired number of tasks to run"
  type        = number
  default     = 1
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

# Capacity Provider Strategy
variable "capacity_provider_strategies" {
  description = "List of capacity provider strategies for the ECS service"
  type = list(object({
    capacity_provider = string
    weight           = number
    base             = optional(number)
  }))
  default = []
}

# Service Discovery
variable "service_discovery_registry_arn" {
  description = "ARN of the service discovery registry"
  type        = string
  default     = null
}

# Auto Scaling
variable "enable_autoscaling" {
  description = "Whether to enable auto scaling for the ECS service"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 3
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

# Load Balancer
variable "enable_nlb_deletion_protection" {
  description = "Whether to enable deletion protection for the NLB"
  type        = bool
  default     = false
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# IAM
variable "task_role_policy_statements" {
  description = "Additional IAM policy statements for the ECS task role"
  type        = list(any)
  default     = []
}

# Twingate Configuration
variable "twingate_url" {
  description = "Twingate tenant URL (e.g., https://mycompany.twingate.com)"
  type        = string
}

variable "twingate_access_token_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing Twingate access token"
  type        = string
}

variable "twingate_refresh_token_secret_arn" {
  description = "ARN of AWS Secrets Manager secret containing Twingate refresh token"
  type        = string
}

variable "log_level" {
  description = "Log level for Twingate connector (0-7, where 7 is most verbose)"
  type        = number
  default     = 3
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