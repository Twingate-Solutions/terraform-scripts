# Credential-free tests: every provider is mocked, so no GCP, Kubernetes or Twingate API is called.
# Run: terraform init -backend=false && terraform test

mock_provider "google" {
  mock_data "google_compute_zones" {
    defaults = {
      names = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email  = "tg-tf-demo-gke-nodes@example-project.iam.gserviceaccount.com"
      member = "serviceAccount:tg-tf-demo-gke-nodes@example-project.iam.gserviceaccount.com"
    }
  }

  # The kubernetes/helm provider blocks base64decode() the cluster CA, even when those providers are mocked
  mock_resource "google_container_cluster" {
    defaults = {
      endpoint = "203.0.113.1"
      master_auth = {
        cluster_ca_certificate = "bW9jay1jYQ==" # base64("mock-ca")
      }
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

mock_provider "twingate" {}

variables {
  gcp_project_id = "example-project"
  tg_network     = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(helm_release.connector) == 2 && length(distinct(helm_release.connector[*].name)) == 2
    error_message = "Expected one uniquely named Helm release per Connector."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      r.repository == "https://twingate.github.io/helm-charts" && r.chart == "connector" && r.version == "0.1.35"
    ])
    error_message = "Connectors must use the pinned Twingate connector chart."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).connector.network == "example" &&
      yamldecode(r.values[0]).connector.logLevel == "error" &&
      !strcontains(r.values[0], "accessToken") && !strcontains(r.values[0], "refreshToken")
    ])
    error_message = "Chart values must set network/logLevel and keep tokens out of the plain values."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).image.repository == "twingate/connector" &&
      yamldecode(r.values[0]).image.tag == "1"
    ])
    error_message = "Chart image must default to twingate/connector:1 (tg_connector_image)."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).env.TWINGATE_LABEL_TERRAFORM_MODULE == "terraform-gcp-gke"
    ])
    error_message = "Connectors must carry the TWINGATE_LABEL_TERRAFORM_MODULE env label."
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
      google_container_cluster.this.private_cluster_config[0].enable_private_nodes == true &&
      google_container_cluster.this.deletion_protection == false
    )
    error_message = "Cluster must use private nodes and be destroyable."
  }

  assert {
    condition     = google_container_cluster.this.node_locations == toset(["us-central1-a", "us-central1-b"])
    error_message = "Nodes should span gcp_zone_count zones."
  }

  assert {
    condition     = length(google_container_cluster.this.master_authorized_networks_config) == 0
    error_message = "No authorized networks block when gcp_gke_authorized_networks is empty."
  }

  assert {
    condition = (
      google_container_node_pool.this.node_count == 1 &&
      google_container_node_pool.this.node_config[0].workload_metadata_config[0].mode == "GKE_METADATA"
    )
    error_message = "Node pool must default to 1 node per zone with the GKE metadata server."
  }

  assert {
    condition = (
      google_compute_router_nat.this.enable_endpoint_independent_mapping == true &&
      google_compute_router_nat.this.enable_dynamic_port_allocation == false &&
      google_compute_router_nat.this.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_IP_RANGES"
    )
    error_message = "Cloud NAT must use EIM and cover the GKE subnet's Pod ranges."
  }

  assert {
    condition = (
      google_compute_subnetwork.gke.secondary_ip_range[0].ip_cidr_range == "10.42.64.0/18" &&
      google_compute_subnetwork.gke.secondary_ip_range[1].ip_cidr_range == "10.42.32.0/20" &&
      google_compute_subnetwork.gke.ip_cidr_range == "10.42.20.0/24"
    )
    error_message = "GKE subnet ranges must sit inside the VPC address plan without overlapping."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-gke.twingate-demo.svc.cluster.local"
    error_message = "Resource address should be the in-cluster Service FQDN."
  }

  assert {
    condition     = twingate_remote_network.this.location == "GOOGLE_CLOUD"
    error_message = "Remote network location must be GOOGLE_CLOUD."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    gcp_zone_count              = 3
    gcp_gke_authorized_networks = ["203.0.113.10/32"]
    tg_connector_count          = 3
    tg_log_level                = "7"
    tg_connector_image          = "registry.example.com:5000/twingate/connector:1.80.0"
    tg_create_service_account   = true
    tg_existing_group_ids       = ["R3JvdXA6MQ=="]
  }

  assert {
    condition     = length(twingate_connector_tokens.this) == 3 && length(helm_release.connector) == 3
    error_message = "Expected one token pair and one Helm release per Connector."
  }

  assert {
    condition = alltrue([
      for i, r in helm_release.connector : nonsensitive(
        one([for s in r.set_sensitive : s.value if s.name == "connector.accessToken"]) == twingate_connector_tokens.this[i].access_token
      )
    ])
    error_message = "Each Helm release must get its own Connector's tokens."
  }

  assert {
    condition     = yamldecode(helm_release.connector[0].values[0]).connector.logLevel == "debug"
    error_message = "tg_log_level 7 must map to the chart's debug level."
  }

  assert {
    condition = alltrue([
      for r in helm_release.connector :
      yamldecode(r.values[0]).image.repository == "registry.example.com:5000/twingate/connector" &&
      yamldecode(r.values[0]).image.tag == "1.80.0"
    ])
    error_message = "tg_connector_image must split into the chart's image repository and tag (registry port kept)."
  }

  assert {
    condition     = [for c in google_container_cluster.this.master_authorized_networks_config[0].cidr_blocks : c.cidr_block] == ["203.0.113.10/32"]
    error_message = "Authorized networks must restrict the control plane when set."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_group) == 2 && length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected demo group, one existing group, and service account access."
  }
}

run "rejects_unsupported_log_level" {
  command = plan

  variables {
    tg_log_level = "5"
  }

  expect_failures = [var.tg_log_level]
}
