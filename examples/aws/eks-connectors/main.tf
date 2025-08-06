# examples/eks/main.tf

terraform {
  required_version = ">= 1.0"
}

# Data sources for existing infrastructure
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

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

# =============================================================================
# BASIC EKS TWINGATE CONNECTOR
# =============================================================================

module "twingate_eks_basic" {
  source = "../../modules/twingate-eks"

  name_prefix = "${var.environment}-twingate-basic"
  subnet_ids  = data.aws_subnets.private.ids

  # Namespace configuration
  namespace        = "twingate"
  create_namespace = true

  # Deployment configuration
  replicas = var.basic_replicas

  # Image configuration
  twingate_image_repository = var.twingate_image_repository
  twingate_image_tag       = var.twingate_image_tag
  image_pull_policy        = "Always"

  # Resource configuration
  resources = {
    requests = {
      cpu    = var.basic_resources.requests.cpu
      memory = var.basic_resources.requests.memory
    }
    limits = {
      cpu    = var.basic_resources.limits.cpu
      memory = var.basic_resources.limits.memory
    }
  }

  # Basic security context
  security_context = {
    privileged                 = false
    run_as_non_root           = true
    run_as_user               = 1000
    run_as_group              = 3000
    read_only_root_filesystem = false
    allow_privilege_escalation = true
  }

  # Twingate configuration
  twingate_url           = var.twingate_url
  twingate_access_token  = var.twingate_access_token
  twingate_refresh_token = var.twingate_refresh_token
  log_level             = var.basic_log_level
  log_analytics         = var.enable_log_analytics
  status_reports_v1     = var.enable_status_reports

  # Additional environment variables
  additional_env_vars = var.additional_env_vars

  labels = merge(var.common_labels, {
    deployment-type = "basic"
    tier           = "connector"
  })
}

# =============================================================================
# PRODUCTION EKS TWINGATE CONNECTOR (Advanced Configuration)
# =============================================================================

module "twingate_eks_production" {
  source = "../../modules/twingate-eks"

  name_prefix = "${var.environment}-twingate-prod"
  subnet_ids  = data.aws_subnets.private.ids

  # Namespace configuration
  namespace        = "twingate-production"
  create_namespace = true
  
  namespace_labels = {
    "pod-security.kubernetes.io/enforce" = "restricted"
    "pod-security.kubernetes.io/audit"   = "restricted"
    "pod-security.kubernetes.io/warn"    = "restricted"
  }

  # Deployment configuration
  replicas = var.production_replicas
  
  deployment_strategy = {
    type = "RollingUpdate"
    rolling_update = {
      max_unavailable = "1"
      max_surge       = "1"
    }
  }

  # Image configuration
  twingate_image_repository = var.twingate_image_repository
  twingate_image_tag       = var.production_image_tag
  image_pull_policy        = "IfNotPresent"
  image_pull_secrets       = var.image_pull_secrets

  # Pod configuration with observability
  pod_annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = "8080"
    "prometheus.io/path"   = "/metrics"
    "fluentd.io/include"   = "true"
  }

  # Node selection and scheduling
  node_selector = var.production_node_selector

  tolerations = var.production_tolerations

  # Anti-affinity for better distribution
  affinity = {
    pod_anti_affinity = {
      preferred_during_scheduling_ignored_during_execution = [
        {
          weight = 100
          pod_affinity_term = {
            label_selector = {
              match_labels = {
                "app.kubernetes.io/name"     = "twingate-connector"
                "app.kubernetes.io/instance" = "${var.environment}-twingate-prod"
              }
            }
            topology_key = "kubernetes.io/hostname"
          }
        }
      ]
    }
  }

  # Resource configuration for production
  resources = {
    requests = {
      cpu    = var.production_resources.requests.cpu
      memory = var.production_resources.requests.memory
    }
    limits = {
      cpu    = var.production_resources.limits.cpu
      memory = var.production_resources.limits.memory
    }
  }

  # Security context
  security_context = {
    privileged                 = false
    run_as_non_root           = true
    run_as_user               = 1000
    run_as_group              = 3000
    read_only_root_filesystem = false
    allow_privilege_escalation = true
  }

  # Auto scaling configuration
  enable_hpa      = true
  hpa_min_replicas = var.production_hpa.min_replicas
  hpa_max_replicas = var.production_hpa.max_replicas

  hpa_metrics = [
    {
      type = "Resource"
      resource = {
        name = "cpu"
        target = {
          type                = "Utilization"
          average_utilization = var.production_hpa.cpu_target
        }
      }
    },
    {
      type = "Resource"
      resource = {
        name = "memory"
        target = {
          type                = "Utilization"
          average_utilization = var.production_hpa.memory_target
        }
      }
    }
  ]

  # Pod Disruption Budget for high availability
  enable_pdb         = true
  pdb_max_unavailable = var.production_pdb_max_unavailable

  # Service configuration for internal communication
  create_service = true
  service_type   = "ClusterIP"
  service_ports = [
    {
      name        = "health"
      port        = 8080
      target_port = 8080
    },
    {
      name        = "metrics"
      port        = 9090
      target_port = 9090
    }
  ]

  service_annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = "9090"
  }

  # Health checks
  liveness_probe = {
    path                  = "/health"
    port                  = 8080
    initial_delay_seconds = var.production_health_checks.liveness.initial_delay
    period_seconds        = var.production_health_checks.liveness.period
    timeout_seconds       = var.production_health_checks.liveness.timeout
    failure_threshold     = var.production_health_checks.liveness.failure_threshold
  }

  readiness_probe = {
    path                  = "/ready"
    port                  = 8080
    initial_delay_seconds = var.production_health_checks.readiness.initial_delay
    period_seconds        = var.production_health_checks.readiness.period
    timeout_seconds       = var.production_health_checks.readiness.timeout
    failure_threshold     = var.production_health_checks.readiness.failure_threshold
  }

  # Network policy for security
  enable_network_policy = var.enable_network_policies
  network_policy_types  = ["Ingress", "Egress"]
  
  network_policy_ingress_rules = [
    {
      ports = [
        {
          port     = 8080
          protocol = "TCP"
        }
      ]
      from = [
        {
          namespace_selector = {
            match_labels = {
              name = "monitoring"
            }
          }
        }
      ]
    }
  ]
  
  network_policy_egress_rules = [
    # Allow HTTPS outbound for Twingate
    {
      ports = [
        {
          port     = 443
          protocol = "TCP"
        }
      ]
      to = []
    },
    # Allow Twingate relay ports
    {
      ports = [
        {
          port     = "30000"
          protocol = "TCP"
        },
        {
          port     = "31000"
          protocol = "TCP"
        }
      ]
      to = []
    },
    # Allow DNS
    {
      ports = [
        {
          port     = 53
          protocol = "UDP"
        },
        {
          port     = 53
          protocol = "TCP"
        }
      ]
      to = []
    }
  ]

  # Volume mounts for configuration
  volumes = var.additional_volumes
  volume_mounts = var.additional_volume_mounts

  # Twingate configuration
  twingate_url           = var.twingate_url
  twingate_access_token  = var.twingate_access_token
  twingate_refresh_token = var.twingate_refresh_token
  log_level             = var.production_log_level
  log_analytics         = var.enable_log_analytics
  status_reports_v1     = var.enable_status_reports

  # Additional environment variables
  additional_env_vars = merge(var.additional_env_vars, var.production_env_vars)

  labels = merge(var.common_labels, {
    deployment-type = "production"
    tier           = "connector"
    monitoring     = "enabled"
  })
}

# =============================================================================
# DEVELOPMENT EKS TWINGATE CONNECTOR (Minimal Configuration)
# =============================================================================

module "twingate_eks_development" {
  count = var.enable_development_deployment ? 1 : 0
  
  source = "../../modules/twingate-eks"

  name_prefix = "${var.environment}-twingate-dev"
  subnet_ids  = data.aws_subnets.private.ids

  # Namespace configuration
  namespace        = "twingate-dev"
  create_namespace = true

  # Minimal deployment configuration
  replicas = 1

  # Resource configuration for development
  resources = {
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "128Mi"
    }
  }

  # Relaxed security context for development
  security_context = {
    privileged                 = false
    run_as_non_root           = false
    read_only_root_filesystem = false
    allow_privilege_escalation = true
  }

  # Twingate configuration
  twingate_url           = var.twingate_dev_url != "" ? var.twingate_dev_url : var.twingate_url
  twingate_access_token  = var.twingate_dev_access_token != "" ? var.twingate_dev_access_token : var.twingate_access_token
  twingate_refresh_token = var.twingate_dev_refresh_token != "" ? var.twingate_dev_refresh_token : var.twingate_refresh_token
  log_level             = 7  # Maximum logging for development
  log_analytics         = false
  status_reports_v1     = false

  labels = merge(var.common_labels, {
    deployment-type = "development"
    tier           = "connector"
  })
}