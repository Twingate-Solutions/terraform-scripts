# modules/twingate-eks/variables.tf

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "twingate"
}

variable "subnet_ids" {
  description = "List of subnet IDs where the EKS cluster nodes are deployed"
  type        = list(string)
}

# Namespace Configuration
variable "namespace" {
  description = "Kubernetes namespace for Twingate connector"
  type        = string
  default     = "twingate"
}

variable "create_namespace" {
  description = "Whether to create the Kubernetes namespace"
  type        = bool
  default     = true
}

variable "namespace_labels" {
  description = "Labels to apply to the namespace"
  type        = map(string)
  default     = {}
}

# Service Account Configuration
variable "service_account_annotations" {
  description = "Annotations to apply to the service account"
  type        = map(string)
  default     = {}
}

# Image Configuration
variable "twingate_image_repository" {
  description = "Twingate connector image repository"
  type        = string
  default     = "twingate/connector"
}

variable "twingate_image_tag" {
  description = "Twingate connector image tag"
  type        = string
  default     = "latest"
}

variable "image_pull_policy" {
  description = "Image pull policy for the Twingate connector"
  type        = string
  default     = "Always"
  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "Image pull policy must be Always, IfNotPresent, or Never."
  }
}

variable "image_pull_secrets" {
  description = "List of image pull secrets"
  type        = list(string)
  default     = []
}

# Deployment Configuration
variable "replicas" {
  description = "Number of Twingate connector replicas"
  type        = number
  default     = 1
}

variable "deployment_strategy" {
  description = "Deployment strategy configuration"
  type = object({
    type = string
    rolling_update = optional(object({
      max_unavailable = optional(string, "25%")
      max_surge       = optional(string, "25%")
    }))
  })
  default = {
    type = "RollingUpdate"
    rolling_update = {
      max_unavailable = "25%"
      max_surge       = "25%"
    }
  }
}

# Pod Configuration
variable "pod_annotations" {
  description = "Annotations to apply to the pods"
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Node selector for pod assignment"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for pod assignment"
  type = list(object({
    key      = optional(string)
    operator = optional(string, "Equal")
    value    = optional(string)
    effect   = optional(string)
  }))
  default = []
}

variable "affinity" {
  description = "Affinity configuration for pod assignment"
  type        = any
  default     = null
}

# Resources Configuration
variable "resources" {
  description = "Resource requests and limits for the Twingate connector"
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
      cpu    = "500m"
      memory = "256Mi"
    }
  }
}

# Security Context
variable "security_context" {
  description = "Security context for the Twingate connector container"
  type = object({
    privileged                 = optional(bool, false)
    run_as_non_root           = optional(bool, true)
    run_as_user               = optional(number, 1000)
    run_as_group              = optional(number, 3000)
    read_only_root_filesystem = optional(bool, false)
    allow_privilege_escalation = optional(bool, true)
  })
  default = {
    privileged                 = false
    run_as_non_root           = true
    run_as_user               = 1000
    run_as_group              = 3000
    read_only_root_filesystem = false
    allow_privilege_escalation = true
  }
}

variable "create_security_context_constraints" {
  description = "Whether to create Security Context Constraints (for OpenShift)"
  type        = bool
  default     = false
}

# Health Checks
variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    path                  = string
    port                  = number
    initial_delay_seconds = optional(number, 30)
    period_seconds        = optional(number, 10)
    timeout_seconds       = optional(number, 5)
    success_threshold     = optional(number, 1)
    failure_threshold     = optional(number, 3)
  })
  default = null
}

variable "readiness_probe" {
  description = "Readiness probe configuration"
  type = object({
    path                  = string
    port                  = number
    initial_delay_seconds = optional(number, 5)
    period_seconds        = optional(number, 10)
    timeout_seconds       = optional(number, 5)
    success_threshold     = optional(number, 1)
    failure_threshold     = optional(number, 3)
  })
  default = null
}

# Volumes and Volume Mounts
variable "volumes" {
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

variable "volume_mounts" {
  description = "Additional volume mounts"
  type = list(object({
    name       = string
    mount_path = string
    read_only  = optional(bool, false)
  }))
  default = []
}

# Horizontal Pod Autoscaler
variable "enable_hpa" {
  description = "Whether to enable Horizontal Pod Autoscaler"
  type        = bool
  default     = false
}

variable "hpa_min_replicas" {
  description = "Minimum number of replicas for HPA"
  type        = number
  default     = 1
}

variable "hpa_max_replicas" {
  description = "Maximum number of replicas for HPA"
  type        = number
  default     = 3
}

variable "hpa_metrics" {
  description = "HPA metrics configuration"
  type = list(object({
    type = string
    resource = optional(object({
      name = string
      target = object({
        type                = string
        average_utilization = optional(number)
        average_value       = optional(string)
      })
    }))
  }))
  default = [
    {
      type = "Resource"
      resource = {
        name = "cpu"
        target = {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  ]
}

# Pod Disruption Budget
variable "enable_pdb" {
  description = "Whether to enable Pod Disruption Budget"
  type        = bool
  default     = false
}

variable "pdb_min_available" {
  description = "Minimum available pods for PDB (mutually exclusive with max_unavailable)"
  type        = string
  default     = null
}

variable "pdb_max_unavailable" {
  description = "Maximum unavailable pods for PDB (mutually exclusive with min_available)"
  type        = string
  default     = "1"
}

# Service Configuration
variable "create_service" {
  description = "Whether to create a Kubernetes service"
  type        = bool
  default     = false
}

variable "service_type" {
  description = "Type of Kubernetes service"
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer", "ExternalName"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, LoadBalancer, or ExternalName."
  }
}

variable "service_ports" {
  description = "Service ports configuration"
  type = list(object({
    name        = string
    port        = number
    target_port = number
    protocol    = optional(string, "TCP")
  }))
  default = []
}

variable "service_annotations" {
  description = "Annotations to apply to the service"
  type        = map(string)
  default     = {}
}

variable "service_cluster_ip" {
  description = "Cluster IP for the service"
  type        = string
  default     = null
}

variable "service_load_balancer_ip" {
  description = "Load balancer IP for the service"
  type        = string
  default     = null
}

variable "service_load_balancer_source_ranges" {
  description = "Load balancer source ranges for the service"
  type        = list(string)
  default     = null
}

# Network Policy
variable "enable_network_policy" {
  description = "Whether to create a network policy"
  type        = bool
  default     = false
}

variable "network_policy_types" {
  description = "Types of network policy (Ingress, Egress, or both)"
  type        = list(string)
  default     = ["Ingress", "Egress"]
}

variable "network_policy_ingress_rules" {
  description = "Network policy ingress rules"
  type        = any
  default     = []
}

variable "network_policy_egress_rules" {
  description = "Network policy egress rules"
  type        = any
  default     = []
}

# Environment Variables
variable "additional_env_vars" {
  description = "Additional environment variables"
  type        = map(string)
  default     = {}
}

# Twingate Configuration
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

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}