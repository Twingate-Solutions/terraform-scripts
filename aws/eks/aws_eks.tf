##############################################################
#
# EKS Cluster & IAM
#
##############################################################

data "aws_partition" "current" {}

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# IAM names are account-global: name_prefix lets the module run in several regions
# of one account. IAM caps name_prefix at 38 chars; app_name is truncated to fit.
resource "aws_iam_role" "cluster" {
  name_prefix        = "${substr(var.app_name, 0, 25)}-eks-cluster-"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = "${var.app_name}-eks"
  version  = var.aws_eks_kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  # Access entries only (no aws-auth ConfigMap); the identity running Terraform
  # becomes cluster admin so the helm/kubernetes providers can deploy into it.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Public endpoint so Terraform and kubectl can reach the API from outside the VPC
  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.aws_eks_public_access_cidrs
  }

  # Demo cluster: auto-upgrade at end of standard support instead of paying for extended support
  upgrade_policy {
    support_type = "STANDARD"
  }

  # IAM permissions must exist before and outlive the cluster, or EKS cannot clean up ENIs/SGs
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

##############################################################
#
# Managed Node Group (private subnets)
#
##############################################################

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name_prefix        = "${substr(var.app_name, 0, 28)}-eks-node-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# Launch template only to enforce IMDSv2 and an encrypted root volume. No security
# groups here, so EKS attaches the cluster security group to the nodes.
resource "aws_launch_template" "node" {
  name_prefix            = "${var.app_name}-eks-node-"
  update_default_version = true

  # Hop limit 1 keeps pods (non-hostNetwork) away from the node role credentials
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  # provider default_tags do not propagate to ASG-launched instances
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-eks-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-eks-node" })
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.app_name}-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = [var.aws_eks_node_instance_type]

  scaling_config {
    desired_size = var.aws_eks_node_count
    min_size     = var.aws_eks_node_count
    max_size     = var.aws_eks_node_count
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  # Nodes need the NAT route to join the cluster and pull images
  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_route.private_default,
    aws_route_table_association.private,
  ]
}

##############################################################
#
# Twingate Connectors (one Helm release per Connector)
#
##############################################################

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.aws_eks_namespace
  }

  depends_on = [aws_eks_node_group.this]
}

locals {
  # Split "<repository>:<tag>" for the Helm chart's image values
  connector_image = regex("^(?P<repository>.+):(?P<tag>[^:/]+)$", var.tg_connector_image)

  # The chart maps a named level to TWINGATE_LOG_LEVEL (error = 3)
  connector_log_level = {
    "3" = "error"
    "4" = "warning"
    "6" = "info"
    "7" = "debug"
  }[var.tg_log_level]

  # Shared pod label so Connector pods from different releases repel each other
  connector_pod_labels = {
    "app.kubernetes.io/part-of" = "${var.app_name}-twingate-connectors"
  }
}

# Values keys verified against stable/connector/values.yaml and templates/deployment.yaml
# in github.com/Twingate/helm-charts (chart 0.1.35). The chart hard-codes
# TWINGATE_LABEL_DEPLOYED_BY=helm, so a separate label records this module instead of
# adding a duplicate env entry.
resource "helm_release" "connector" {
  count = var.tg_connector_count

  name       = "twingate-connector-${count.index + 1}"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://twingate.github.io/helm-charts"
  chart      = "connector"
  version    = var.tg_helm_chart_version

  values = [yamlencode({
    image = {
      repository = local.connector_image.repository
      tag        = local.connector_image.tag
    }

    connector = {
      network      = var.tg_network
      logLevel     = local.connector_log_level
      logAnalytics = var.tg_log_analytics_version
    }

    env = {
      TWINGATE_LABEL_TERRAFORM_MODULE = "terraform-aws-eks"
    }

    additionalLabels = local.connector_pod_labels

    # Soft anti-affinity: prefer one Connector per zone, still schedule if zones < Connectors
    affinity = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [{
          weight = 100
          podAffinityTerm = {
            topologyKey   = "topology.kubernetes.io/zone"
            labelSelector = { matchLabels = local.connector_pod_labels }
          }
        }]
      }
    }
  })]

  # Chart renders these into its own Secret (envFrom). Also kept in the Helm release
  # Secret and Terraform state.
  set_sensitive = [
    {
      name  = "connector.accessToken"
      value = twingate_connector_tokens.this[count.index].access_token
      type  = "string"
    },
    {
      name  = "connector.refreshToken"
      value = twingate_connector_tokens.this[count.index].refresh_token
      type  = "string"
    },
  ]

  depends_on = [aws_eks_node_group.this]
}

##############################################################
#
# Private Resource (nginx Deployment + ClusterIP Service)
#
##############################################################

locals {
  private_resource_labels = {
    "app.kubernetes.io/name" = "web-eks"
  }
}

resource "kubernetes_deployment_v1" "private_resource" {
  metadata {
    name      = "web-eks"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.private_resource_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.private_resource_labels
    }

    template {
      metadata {
        labels = local.private_resource_labels
      }

      spec {
        container {
          name  = "web"
          image = "public.ecr.aws/nginx/nginx:stable-alpine"

          port {
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [aws_eks_node_group.this]
}

# ClusterIP only: reachable inside the cluster, so only via the in-cluster Connectors.
# web-<deployment> keeps Resource addresses unique when several modules share a tenant.
resource "kubernetes_service_v1" "private_resource" {
  metadata {
    name      = "web-eks"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = local.private_resource_labels

    port {
      name        = "http"
      port        = 80
      target_port = "80"
      protocol    = "TCP"
    }
  }
}
