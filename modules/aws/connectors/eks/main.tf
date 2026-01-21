# modules/twingate-eks/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

data "aws_subnet" "selected" {
  count = length(var.subnet_ids)
  id    = var.subnet_ids[count.index]
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected[0].vpc_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Kubernetes namespace
resource "kubernetes_namespace" "twingate" {
  count = var.create_namespace ? 1 : 0
  
  metadata {
    name = var.namespace
    
    labels = merge(var.namespace_labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
  }
}

# Service Account for Twingate connector
resource "kubernetes_service_account" "twingate_connector" {
  metadata {
    name      = "${var.name_prefix}-twingate-connector"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
    
    annotations = var.service_account_annotations
  }
  
  depends_on = [kubernetes_namespace.twingate]
}

# Secret for Twingate credentials
resource "kubernetes_secret" "twingate_credentials" {
  metadata {
    name      = "${var.name_prefix}-twingate-credentials"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
  }

  data = {
    TWINGATE_ACCESS_TOKEN  = var.twingate_access_token
    TWINGATE_REFRESH_TOKEN = var.twingate_refresh_token
  }

  type = "Opaque"
  
  depends_on = [kubernetes_namespace.twingate]
}

# ConfigMap for Twingate configuration
resource "kubernetes_config_map" "twingate_config" {
  metadata {
    name      = "${var.name_prefix}-twingate-config"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
  }

  data = {
    TWINGATE_URL              = var.twingate_url
    TWINGATE_LOG_LEVEL        = tostring(var.log_level)
    TWINGATE_LOG_ANALYTICS    = tostring(var.log_analytics)
    TWINGATE_STATUS_REPORTS_V1 = tostring(var.status_reports_v1)
  }
  
  depends_on = [kubernetes_namespace.twingate]
}

# Security Context Constraints (if needed for OpenShift)
resource "kubernetes_manifest" "security_context_constraints" {
  count = var.create_security_context_constraints ? 1 : 0
  
  manifest = {
    apiVersion = "security.openshift.io/v1"
    kind       = "SecurityContextConstraints"
    metadata = {
      name = "${var.name_prefix}-twingate-scc"
      labels = merge(var.labels, {
        "app.kubernetes.io/name"     = "twingate-connector"
        "app.kubernetes.io/instance" = var.name_prefix
      })
    }
    allowHostDirVolumePlugin = false
    allowHostIPC             = false
    allowHostNetwork         = true
    allowHostPID             = false
    allowHostPorts           = false
    allowPrivilegeEscalation = true
    allowPrivilegedContainer = false
    allowedCapabilities      = ["NET_ADMIN"]
    defaultAddCapabilities   = []
    fsGroup = {
      type = "RunAsAny"
    }
    readOnlyRootFilesystem = false
    requiredDropCapabilities = ["KILL", "MKNOD", "SETUID", "SETGID"]
    runAsUser = {
      type = "RunAsAny"
    }
    seLinuxContext = {
      type = "MustRunAs"
    }
    users = ["system:serviceaccount:${var.namespace}:${kubernetes_service_account.twingate_connector.metadata[0].name}"]
  }
}

# Deployment
resource "kubernetes_deployment" "twingate_connector" {
  metadata {
    name      = "${var.name_prefix}-twingate-connector"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
      "app.kubernetes.io/version"  = var.twingate_image_tag
    })
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "twingate-connector"
        "app.kubernetes.io/instance" = var.name_prefix
      }
    }

    template {
      metadata {
        labels = merge(var.labels, {
          "app.kubernetes.io/name"     = "twingate-connector"
          "app.kubernetes.io/instance" = var.name_prefix
          "app.kubernetes.io/version"  = var.twingate_image_tag
        })
        
        annotations = var.pod_annotations
      }

      spec {
        service_account_name            = kubernetes_service_account.twingate_connector.metadata[0].name
        automount_service_account_token = true
        
        # Node selector
        dynamic "node_selector" {
          for_each = var.node_selector
          content {
            node_selector.key = node_selector.value
          }
        }
        
        # Tolerations
        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key      = lookup(toleration.value, "key", null)
            operator = lookup(toleration.value, "operator", "Equal")
            value    = lookup(toleration.value, "value", null)
            effect   = lookup(toleration.value, "effect", null)
          }
        }
        
        # Affinity
        dynamic "affinity" {
          for_each = var.affinity != null ? [var.affinity] : []
          content {
            dynamic "node_affinity" {
              for_each = lookup(affinity.value, "node_affinity", null) != null ? [affinity.value.node_affinity] : []
              content {
                dynamic "required_during_scheduling_ignored_during_execution" {
                  for_each = lookup(node_affinity.value, "required_during_scheduling_ignored_during_execution", null) != null ? [node_affinity.value.required_during_scheduling_ignored_during_execution] : []
                  content {
                    dynamic "node_selector_term" {
                      for_each = required_during_scheduling_ignored_during_execution.value.node_selector_terms
                      content {
                        dynamic "match_expressions" {
                          for_each = lookup(node_selector_term.value, "match_expressions", [])
                          content {
                            key      = match_expressions.value.key
                            operator = match_expressions.value.operator
                            values   = lookup(match_expressions.value, "values", [])
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            
            dynamic "pod_anti_affinity" {
              for_each = lookup(affinity.value, "pod_anti_affinity", null) != null ? [affinity.value.pod_anti_affinity] : []
              content {
                dynamic "preferred_during_scheduling_ignored_during_execution" {
                  for_each = lookup(pod_anti_affinity.value, "preferred_during_scheduling_ignored_during_execution", [])
                  content {
                    weight = preferred_during_scheduling_ignored_during_execution.value.weight
                    pod_affinity_term {
                      label_selector {
                        dynamic "match_labels" {
                          for_each = lookup(preferred_during_scheduling_ignored_during_execution.value.pod_affinity_term.label_selector, "match_labels", {})
                          content {
                            match_labels.key = match_labels.value
                          }
                        }
                      }
                      topology_key = preferred_during_scheduling_ignored_during_execution.value.pod_affinity_term.topology_key
                    }
                  }
                }
              }
            }
          }
        }

        container {
          name  = "twingate-connector"
          image = "${var.twingate_image_repository}:${var.twingate_image_tag}"
          
          image_pull_policy = var.image_pull_policy

          env_from {
            config_map_ref {
              name = kubernetes_config_map.twingate_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.twingate_credentials.metadata[0].name
            }
          }

          # Additional environment variables
          dynamic "env" {
            for_each = var.additional_env_vars
            content {
              name  = env.key
              value = env.value
            }
          }

          # Resources
          resources {
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
          }

          # Security context
          security_context {
            capabilities {
              add = ["NET_ADMIN"]
            }
            privileged                = var.security_context.privileged
            run_as_non_root          = var.security_context.run_as_non_root
            run_as_user              = var.security_context.run_as_user
            run_as_group             = var.security_context.run_as_group
            read_only_root_filesystem = var.security_context.read_only_root_filesystem
            allow_privilege_escalation = var.security_context.allow_privilege_escalation
          }

          # Liveness probe
          dynamic "liveness_probe" {
            for_each = var.liveness_probe != null ? [var.liveness_probe] : []
            content {
              http_get {
                path = liveness_probe.value.path
                port = liveness_probe.value.port
              }
              initial_delay_seconds = liveness_probe.value.initial_delay_seconds
              period_seconds        = liveness_probe.value.period_seconds
              timeout_seconds       = liveness_probe.value.timeout_seconds
              success_threshold     = liveness_probe.value.success_threshold
              failure_threshold     = liveness_probe.value.failure_threshold
            }
          }

          # Readiness probe
          dynamic "readiness_probe" {
            for_each = var.readiness_probe != null ? [var.readiness_probe] : []
            content {
              http_get {
                path = readiness_probe.value.path
                port = readiness_probe.value.port
              }
              initial_delay_seconds = readiness_probe.value.initial_delay_seconds
              period_seconds        = readiness_probe.value.period_seconds
              timeout_seconds       = readiness_probe.value.timeout_seconds
              success_threshold     = readiness_probe.value.success_threshold
              failure_threshold     = readiness_probe.value.failure_threshold
            }
          }

          # Volume mounts
          dynamic "volume_mount" {
            for_each = var.volume_mounts
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
              read_only  = lookup(volume_mount.value, "read_only", false)
            }
          }
        }

        # Volumes
        dynamic "volume" {
          for_each = var.volumes
          content {
            name = volume.value.name
            
            dynamic "config_map" {
              for_each = lookup(volume.value, "config_map", null) != null ? [volume.value.config_map] : []
              content {
                name = config_map.value.name
              }
            }
            
            dynamic "secret" {
              for_each = lookup(volume.value, "secret", null) != null ? [volume.value.secret] : []
              content {
                secret_name = secret.value.secret_name
              }
            }
            
            dynamic "empty_dir" {
              for_each = lookup(volume.value, "empty_dir", null) != null ? [volume.value.empty_dir] : []
              content {
                medium = lookup(empty_dir.value, "medium", "")
              }
            }
          }
        }

        # Image pull secrets
        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secrets
          content {
            name = image_pull_secrets.value
          }
        }
      }
    }

    strategy {
      type = var.deployment_strategy.type
      
      dynamic "rolling_update" {
        for_each = var.deployment_strategy.type == "RollingUpdate" ? [var.deployment_strategy.rolling_update] : []
        content {
          max_unavailable = rolling_update.value.max_unavailable
          max_surge       = rolling_update.value.max_surge
        }
      }
    }
  }
  
  depends_on = [
    kubernetes_namespace.twingate,
    kubernetes_secret.twingate_credentials,
    kubernetes_config_map.twingate_config
  ]
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v2" "twingate_connector" {
  count = var.enable_hpa ? 1 : 0
  
  metadata {
    name      = "${var.name_prefix}-twingate-connector-hpa"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"      = "twingate-connector"
      "app.kubernetes.io/instance"  = var.name_prefix
      "app.kubernetes.io/component" = "hpa"
    })
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.twingate_connector.metadata[0].name
    }

    min_replicas = var.hpa_min_replicas
    max_replicas = var.hpa_max_replicas

    dynamic "metric" {
      for_each = var.hpa_metrics
      content {
        type = metric.value.type
        
        dynamic "resource" {
          for_each = metric.value.type == "Resource" ? [metric.value.resource] : []
          content {
            name = resource.value.name
            target {
              type                = resource.value.target.type
              average_utilization = lookup(resource.value.target, "average_utilization", null)
              average_value       = lookup(resource.value.target, "average_value", null)
            }
          }
        }
      }
    }
  }
}

# Pod Disruption Budget
resource "kubernetes_pod_disruption_budget_v1" "twingate_connector" {
  count = var.enable_pdb ? 1 : 0
  
  metadata {
    name      = "${var.name_prefix}-twingate-connector-pdb"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"      = "twingate-connector"
      "app.kubernetes.io/instance"  = var.name_prefix
      "app.kubernetes.io/component" = "pdb"
    })
  }

  spec {
    min_available = var.pdb_min_available
    max_unavailable = var.pdb_max_unavailable
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "twingate-connector"
        "app.kubernetes.io/instance" = var.name_prefix
      }
    }
  }
}

# Service (if needed for health checks or service discovery)
resource "kubernetes_service" "twingate_connector" {
  count = var.create_service ? 1 : 0
  
  metadata {
    name      = "${var.name_prefix}-twingate-connector"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
    
    annotations = var.service_annotations
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    }

    dynamic "port" {
      for_each = var.service_ports
      content {
        name        = port.value.name
        port        = port.value.port
        target_port = port.value.target_port
        protocol    = lookup(port.value, "protocol", "TCP")
      }
    }

    type                    = var.service_type
    cluster_ip             = var.service_cluster_ip
    load_balancer_ip       = var.service_load_balancer_ip
    load_balancer_source_ranges = var.service_load_balancer_source_ranges
  }
}

# Network Policy (if enabled)
resource "kubernetes_network_policy" "twingate_connector" {
  count = var.enable_network_policy ? 1 : 0
  
  metadata {
    name      = "${var.name_prefix}-twingate-connector-netpol"
    namespace = var.namespace
    
    labels = merge(var.labels, {
      "app.kubernetes.io/name"     = "twingate-connector"
      "app.kubernetes.io/instance" = var.name_prefix
    })
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "twingate-connector"
        "app.kubernetes.io/instance" = var.name_prefix
      }
    }

    policy_types = var.network_policy_types

    dynamic "ingress" {
      for_each = var.network_policy_ingress_rules
      content {
        dynamic "ports" {
          for_each = lookup(ingress.value, "ports", [])
          content {
            port     = lookup(ports.value, "port", null)
            protocol = lookup(ports.value, "protocol", "TCP")
          }
        }
        
        dynamic "from" {
          for_each = lookup(ingress.value, "from", [])
          content {
            dynamic "pod_selector" {
              for_each = lookup(from.value, "pod_selector", null) != null ? [from.value.pod_selector] : []
              content {
                match_labels = pod_selector.value.match_labels
              }
            }
            
            dynamic "namespace_selector" {
              for_each = lookup(from.value, "namespace_selector", null) != null ? [from.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value.match_labels
              }
            }
          }
        }
      }
    }

    dynamic "egress" {
      for_each = var.network_policy_egress_rules
      content {
        dynamic "ports" {
          for_each = lookup(egress.value, "ports", [])
          content {
            port     = lookup(ports.value, "port", null)
            protocol = lookup(ports.value, "protocol", "TCP")
          }
        }
        
        dynamic "to" {
          for_each = lookup(egress.value, "to", [])
          content {
            dynamic "pod_selector" {
              for_each = lookup(to.value, "pod_selector", null) != null ? [to.value.pod_selector] : []
              content {
                match_labels = pod_selector.value.match_labels
              }
            }
            
            dynamic "namespace_selector" {
              for_each = lookup(to.value, "namespace_selector", null) != null ? [to.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value.match_labels
              }
            }
          }
        }
      }
    }
  }
}