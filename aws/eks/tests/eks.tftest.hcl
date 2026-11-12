# Credential-free tests: every provider is mocked, so no AWS, Kubernetes, Helm or Twingate API is called.
# Run: terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  # aws_eks_node_group validates the launch template ID format
  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-0123456789abcdef0"
    }
  }
}

mock_provider "twingate" {}

mock_provider "helm" {}

mock_provider "kubernetes" {}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(helm_release.connector) == 2 && length(twingate_connector_tokens.this) == 2
    error_message = "Expected one Helm release and one token pair per Connector."
  }

  assert {
    condition     = helm_release.connector[*].name == ["twingate-connector-1", "twingate-connector-2"]
    error_message = "Each Connector needs its own Helm release, named twingate-connector-<n>."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).image.repository == "twingate/connector" && yamldecode(r.values[0]).image.tag == "1"
    ])
    error_message = "Connector image must come from tg_connector_image (twingate/connector:1)."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : yamldecode(r.values[0]).env.TWINGATE_LABEL_TERRAFORM_MODULE == "terraform-aws-eks"])
    error_message = "Connector pods must carry the terraform-aws-eks module label."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      toset([for s in r.set_sensitive : s.name]) == toset(["connector.accessToken", "connector.refreshToken"])
    ])
    error_message = "Tokens must be passed with set_sensitive."
  }

  assert {
    condition = (
      startswith(aws_iam_role.cluster.name_prefix, "tg-tf-demo-") && length(aws_iam_role.cluster.name_prefix) <= 38 &&
      startswith(aws_iam_role.node.name_prefix, "tg-tf-demo-") && length(aws_iam_role.node.name_prefix) <= 38
    )
    error_message = "IAM roles must use IAM-valid name_prefixes (<= 38 chars) so regions do not collide."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected public and private subnets in aws_az_count (2) AZs."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : r.repository == "https://twingate.github.io/helm-charts" && r.chart == "connector"])
    error_message = "Connectors must use the Twingate connector chart."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : yamldecode(r.values[0]).connector.network == "example"])
    error_message = "Connector network must come from tg_network."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : !can(yamldecode(r.values[0]).connector.accessToken) && !can(yamldecode(r.values[0]).connector.refreshToken)])
    error_message = "Tokens must not be passed through plaintext values."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : yamldecode(r.values[0]).connector.logLevel == "error"])
    error_message = "tg_log_level 3 should map to the chart's error level."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API" && aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "Cluster must use access entries and bootstrap creator admin."
  }

  assert {
    condition     = aws_eks_cluster.this.version == "1.36"
    error_message = "Unexpected default Kubernetes version."
  }

  assert {
    condition     = aws_eks_node_group.this.scaling_config[0].desired_size == 2
    error_message = "Expected two nodes by default."
  }

  assert {
    condition     = aws_launch_template.node.metadata_options[0].http_tokens == "required" && aws_launch_template.node.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Nodes must require IMDSv2 and encrypt the root volume."
  }

  assert {
    condition     = kubernetes_service_v1.private_resource.spec[0].type == "ClusterIP"
    error_message = "Demo service must not be exposed outside the cluster."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-eks.twingate-demo.svc.cluster.local"
    error_message = "Resource address should be the in-cluster Service FQDN web-eks.<namespace>.svc.cluster.local."
  }

  assert {
    condition     = length(twingate_service_account.this) == 0 && length(data.twingate_security_policy.this) == 0
    error_message = "Service account and policy lookup must be off by default."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    aws_az_count              = 3
    tg_connector_count        = 3
    tg_log_level              = "7"
    tg_security_policy_name   = "Example Policy"
    tg_create_service_account = true
    tg_existing_group_ids     = ["R3JvdXA6MQ==", "R3JvdXA6Mg=="]
    tg_connector_image        = "registry.example.com:5000/twingate/connector:1.80.0"
    aws_eks_namespace         = "tg-demo"
  }

  assert {
    condition = alltrue([
      for i, r in helm_release.connector : nonsensitive(
        one([for s in r.set_sensitive : s.value if s.name == "connector.accessToken"]) == twingate_connector_tokens.this[i].access_token &&
        one([for s in r.set_sensitive : s.value if s.name == "connector.refreshToken"]) == twingate_connector_tokens.this[i].refresh_token
      )
    ])
    error_message = "Each Helm release must carry its own Connector's token pair."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).image.repository == "registry.example.com:5000/twingate/connector" && yamldecode(r.values[0]).image.tag == "1.80.0"
    ])
    error_message = "A registry host:port must stay in the repository; only the tag is split off."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-eks.tg-demo.svc.cluster.local"
    error_message = "Resource address must follow aws_eks_namespace."
  }

  assert {
    condition     = length(helm_release.connector) == 3 && length(twingate_connector_tokens.this) == 3
    error_message = "Expected one Helm release per Connector."
  }

  assert {
    condition     = toset(aws_eks_node_group.this.subnet_ids) == toset(aws_subnet.private[*].id)
    error_message = "Nodes must run in the private subnets."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.vpc_config[0].subnet_ids) == toset(aws_subnet.private[*].id)
    error_message = "Cluster ENIs must sit in the private subnets."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : r.namespace == kubernetes_namespace_v1.this.metadata[0].name])
    error_message = "Connector releases must install into the demo namespace."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : yamldecode(r.values[0]).connector.logLevel == "debug"])
    error_message = "tg_log_level 7 should map to the chart's debug level."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_group) == 3
    error_message = "Expected demo group plus two existing groups."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }

  assert {
    condition     = length(data.twingate_security_policy.this) == 1
    error_message = "Security policy lookup expected when tg_security_policy_name is set."
  }
}

run "single_az_rejected" {
  command = plan

  variables {
    aws_az_count = 1
  }

  expect_failures = [var.aws_az_count]
}

# Mocked region has 3 AZs
run "too_few_azs_rejected" {
  command = plan

  variables {
    aws_az_count = 4
  }

  expect_failures = [aws_vpc.this]
}

run "unsupported_log_analytics_rejected" {
  command = plan

  variables {
    tg_log_analytics_version = "v3"
  }

  expect_failures = [var.tg_log_analytics_version]
}

run "invalid_connector_image_rejected" {
  command = plan

  variables {
    tg_connector_image = "twingate/connector"
  }

  expect_failures = [var.tg_connector_image]
}

run "unsupported_log_level_rejected" {
  command = plan

  variables {
    tg_log_level = "5"
  }

  expect_failures = [var.tg_log_level]
}
