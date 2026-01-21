# examples/eks/variables.tf

# =============================================================================
# GENERAL CONFIGURATION
# =============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "twingate"
  }
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

variable "enable_log_analytics" {
  description = "Whether to enable log analytics for Twingate"
  type        = bool
  default     = true
}

variable "enable_status_reports" {
  description = "Whether to enable status reports v1 for Twingate"
  type        = bool
  default     = true
}

# Development Twingate configuration (optional separate tenant)
variable "twingate_dev_url" {
  description = "Twingate development tenant URL (optional)"
  type        = string
  default     = ""
}

variable "twingate_dev_access_token" {
  description = "Twingate development access token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twingate_dev_refresh_token" {
  description = "Twingate development refresh token (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# IMAGE CONFIGURATION
# =============================================================================

variable "twingate_image_repository" {
  description = "Twingate connector image repository"
  type        = string
  default     = "twingate/connector"
}

variable "twingate_image_tag" {
  description = "Twingate connector image tag for basic deployment"
  type        = string
  default     = "latest"
}

variable "production_image_tag" {
  description = "Twingate connector image tag for production deployment"
  type        = string
  default     = "1.60.0"  # Use specific version for production
}

variable "image_pull_secrets" {
  description = "List of image pull secrets for private registries"
  type        = list(string)
  default     = []
}

# =============================================================================
# BASIC DEPLOYMENT CONFIGURATION
# =============================================================================

variable "basic_replicas" {
  description = "Number of replicas for basic deployment"
  type        = number
  default     = 2
}

variable "basic_log_level" {
  description = "Log level for basic deployment (0-7)"
  type        = number
  default     = 3
}

variable "basic_resources" {
  description = "Resource configuration for basic deployment"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "256Mi"
    }
  }
}

# =============================================================================
# PRODUCTION DEPLOYMENT CONFIGURATION
# =============================================================================

variable "production_replicas" {
  description = "Number of replicas for production deployment"
  type        = number
  default     = 3
}

variable "production_log_level" {
  description = "Log level for production deployment (0-7)"
  type        = number
  default     = 4
}

variable "production_resources" {
  description = "Resource configuration for production deployment"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

# Node Selection and Scheduling
variable "production_node_selector" {
  description = "Node selector for production deployment"
  type        = map(string)
  default = {
    "kubernetes.io/arch"        = "amd64"
    "node.kubernetes.io/tier"   = "worker"
  }
}

variable "production_tolerations" {
  description = "Tolerations for production deployment"
  type = list(object({
    key      = optional(string)
    operator = optional(string, "Equal")
    value    = optional(string)
    effect   = optional(string)
  }))
  default = [
    {
      key      = "dedicated"
      operator = "Equal"
      value    = "twingate"
      effect   = "NoSchedule"
    }
  ]
}

# Auto Scaling Configuration
variable "production_hpa" {
  description = "HPA configuration for production deployment"
  type = object({
    min_replicas = number
    max_replicas = number
    cpu_target   = number
    memory_target = number
  })
  default = {
    min_replicas  = 2
    max_replicas  = 10
    cpu_target    = 60
    memory_target = 70
  }
}

variable "production_pdb_max_unavailable" {
  description = "Maximum unavailable pods for production PDB"
  type        = string
  default     = "1"
}

# Health Check Configuration
variable "production_health_checks" {
  description = "Health check configuration for production deployment"
  type = object({
    liveness = object({
      initial_delay    = number
      period          = number
      timeout         = number
      failure_threshold = number
    })
    readiness = object({
      initial_delay    = number
      period          = number
      timeout         = number
      failure_threshold = number
    })
  })
  default = {
    liveness = {
      initial_delay    = 60
      period          = 30
      timeout         = 10
      failure_threshold = 3
    }
    readiness = {
      initial_delay    = 10
      period          = 10
      timeout         = 5
      failure_threshold = 3
    }
  }
}

# =============================================================================
# DEVELOPMENT DEPLOYMENT CONFIGURATION
# =============================================================================

variable "enable_development_deployment" {
  description = "Whether to create a development deployment"
  type        = bool
  default     = false
}

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

variable "enable_network_policies" {
  description = "Whether to enable Kubernetes Network Policies"
  type        = bool
  default     = true
}

variable "create_security_context_constraints" {
  description = "Whether to create Security Context Constraints (for OpenShift)"
  type        = bool
  default     = false
}

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

variable "additional_env_vars" {
  description = "Additional environment variables for all deployments"
  type        = map(string)
  default = {
    "TZ" = "UTC"
  }
}

variable "production_env_vars" {
  description = "Additional environment variables specific to production"
  type        = map(string)
  default = {
    "ENVIRONMENT"           = "production"
    "ENABLE_DEBUG_LOGGING" = "false"
    "METRICS_ENABLED"      = "true"
  }
}

# =============================================================================
# VOLUME CONFIGURATION
# =============================================================================

variable "additional_volumes" {
  description = "Additional volumes to mount"
  type = list(object({
    name = string
    config_map = optional(object({
      name = string
    }))
    secret = optional(object({
      secret_name = string
    }))
    empty_dir = optional(object({
      medium = optional(string)
    }))
  }))
  default = []
}

variable "additional_volume_mounts" {
  description = "Additional volume mounts"
  type = list(object({
    name       = string
    mount_path = string
    read_only  = optional(bool, false)
  }))
  default = []
}

# =============================================================================
# MONITORING AND OBSERVABILITY
# =============================================================================

variable "enable_prometheus_monitoring" {
  description = "Whether to enable Prometheus monitoring annotations"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Whether to create Prometheus ServiceMonitor CRD"
  type        = bool
  default     = false
}

variable "monitoring_namespace" {
  description = "Namespace where monitoring stack is deployed"
  type        = string
  default     = "monitoring"
}

# =============================================================================
# BACKUP AND DISASTER RECOVERY
# =============================================================================

variable "enable_velero_backup" {
  description = "Whether to enable Velero backup annotations"
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "0 2 * * *"  # Daily at 2 AM
}

# =============================================================================
# COST OPTIMIZATION
# =============================================================================

variable "enable_cluster_autoscaler" {
  description = "Whether to enable cluster autoscaler annotations"
  type        = bool
  default     = true
}

variable "enable_spot_instances" {
  description = "Whether to prefer spot instances for scheduling"
  type        = bool
  default     = false
}