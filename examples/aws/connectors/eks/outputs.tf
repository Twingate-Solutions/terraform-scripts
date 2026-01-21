# examples/eks/outputs.tf

# =============================================================================
# BASIC DEPLOYMENT OUTPUTS
# =============================================================================

output "basic_deployment" {
  description = "Basic Twingate connector deployment information"
  value = {
    namespace         = module.twingate_eks_basic.namespace
    deployment_name   = module.twingate_eks_basic.deployment_name
    service_account   = module.twingate_eks_basic.service_account_name
    secret_name       = module.twingate_eks_basic.secret_name
    config_map_name   = module.twingate_eks_basic.config_map_name
    labels           = module.twingate_eks_basic.labels
  }
}

output "basic_deployment_status" {
  description = "Basic deployment status and connection information"
  value = {
    cluster_name = var.eks_cluster_name
    namespace    = module.twingate_eks_basic.namespace
    replicas     = var.basic_replicas
    resources    = var.basic_resources
    log_level    = var.basic_log_level
  }
}

# =============================================================================
# PRODUCTION DEPLOYMENT OUTPUTS
# =============================================================================

output "production_deployment" {
  description = "Production Twingate connector deployment information"
  value = {
    namespace         = module.twingate_eks_production.namespace
    deployment_name   = module.twingate_eks_production.deployment_name
    service_account   = module.twingate_eks_production.service_account_name
    service_name      = module.twingate_eks_production.service_name
    secret_name       = module.twingate_eks_production.secret_name
    config_map_name   = module.twingate_eks_production.config_map_name
    hpa_name         = module.twingate_eks_production.hpa_name
    pdb_name         = module.twingate_eks_production.pdb_name
    network_policy_name = module.twingate_eks_production.network_policy_name
    labels           = module.twingate_eks_production.labels
  }
}

output "production_deployment_config" {
  description = "Production deployment configuration details"
  value = {
    cluster_name     = var.eks_cluster_name
    namespace        = module.twingate_eks_production.namespace
    replicas         = var.production_replicas
    resources        = var.production_resources
    log_level        = var.production_log_level
    hpa_config       = var.production_hpa
    node_selector    = var.production_node_selector
    tolerations      = var.production_tolerations
    health_checks    = var.production_health_checks
  }
}

output "production_monitoring" {
  description = "Production deployment monitoring endpoints"
  value = {
    service_name      = module.twingate_eks_production.service_name
    health_endpoint   = "http://${module.twingate_eks_production.service_name}.${module.twingate_eks_production.namespace}.svc.cluster.local:8080/health"
    metrics_endpoint  = "http://${module.twingate_eks_production.service_name}.${module.twingate_eks_production.namespace}.svc.cluster.local:9090/metrics"
    readiness_endpoint = "http://${module.twingate_eks_production.service_name}.${module.twingate_eks_production.namespace}.svc.cluster.local:8080/ready"
  }
}

# =============================================================================
# DEVELOPMENT DEPLOYMENT OUTPUTS (Conditional)
# =============================================================================

output "development_deployment" {
  description = "Development Twingate connector deployment information"
  value = value = try(
    var.enable_development_deployment ? {
      namespace         = module.twingate_eks_development[0].namespace
      deployment_name   = module.twingate_eks_development[0].deployment_name
      service_account   = module.twingate_eks_development[0].service_account_name
      secret_name       = module.twingate_eks_development[0].secret_name
      config_map_name   = module.twingate_eks_development[0].config_map_name
      labels            = module.twingate_eks_development[0].labels
    } : null,
    null
  )
}

# =============================================================================
# KUBECTL COMMANDS
# =============================================================================

output "kubectl_commands" {
  description = "Useful kubectl commands for managing the deployments"
  value = {
    basic_deployment = {
      get_pods         = "kubectl get pods -n ${module.twingate_eks_basic.namespace} -l app.kubernetes.io/name=twingate-connector"
      get_logs         = "kubectl logs -n ${module.twingate_eks_basic.namespace} -l app.kubernetes.io/name=twingate-connector --tail=100"
      describe_deployment = "kubectl describe deployment ${module.twingate_eks_basic.deployment_name} -n ${module.twingate_eks_basic.namespace}"
      get_events       = "kubectl get events -n ${module.twingate_eks_basic.namespace} --sort-by='.lastTimestamp'"
    }
    production_deployment = {
      get_pods         = "kubectl get pods -n ${module.twingate_eks_production.namespace} -l app.kubernetes.io/name=twingate-connector"
      get_logs         = "kubectl logs -n ${module.twingate_eks_production.namespace} -l app.kubernetes.io/name=twingate-connector --tail=100"
      describe_deployment = "kubectl describe deployment ${module.twingate_eks_production.deployment_name} -n ${module.twingate_eks_production.namespace}"
      get_hpa          = "kubectl get hpa ${module.twingate_eks_production.hpa_name} -n ${module.twingate_eks_production.namespace}"
      get_pdb          = "kubectl get pdb ${module.twingate_eks_production.pdb_name} -n ${module.twingate_eks_production.namespace}"
      get_service      = "kubectl get svc ${module.twingate_eks_production.service_name} -n ${module.twingate_eks_production.namespace}"
      port_forward_health = "kubectl port-forward -n ${module.twingate_eks_production.namespace} svc/${module.twingate_eks_production.service_name} 8080:8080"
      port_forward_metrics = "kubectl port-forward -n ${module.twingate_eks_production.namespace} svc/${module.twingate_eks_production.service_name} 9090:9090"
    }
  }
}

# =============================================================================
# MONITORING AND ALERTING
# =============================================================================

output "monitoring_info" {
  description = "Monitoring and alerting information"
  value = {
    prometheus_annotations_enabled = var.enable_prometheus_monitoring
    service_monitor_enabled       = var.enable_service_monitor
    monitoring_namespace          = var.monitoring_namespace
    production_service_monitor = var.enable_service_monitor ? {
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "ServiceMonitor"
      metadata = {
        name      = "${var.environment}-twingate-prod-monitor"
        namespace = var.monitoring_namespace
      }
      spec = {
        selector = {
          matchLabels = {
            "app.kubernetes.io/name"     = "twingate-connector"
            "app.kubernetes.io/instance" = "${var.environment}-twingate-prod"
          }
        }
        namespaceSelector = {
          matchNames = [module.twingate_eks_production.namespace]
        }
        endpoints = [
          {
            port = "metrics"
            path = "/metrics"
          }
        ]
      }
    } : null
  }
}

# =============================================================================
# BACKUP AND DISASTER RECOVERY
# =============================================================================

output "backup_info" {
  description = "Backup and disaster recovery information"
  value = {
    velero_backup_enabled = var.enable_velero_backup
    backup_schedule      = var.backup_schedule
      velero_backup_annotation = var.enable_velero_backup ? {
    "backup.velero.io/backup-volumes-excludes" = "twingate-data"
    "backup.velero.io/include-resources"       = "deployment,configmap,secret,service"
  } : null
}
