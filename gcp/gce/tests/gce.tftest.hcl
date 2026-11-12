# Credential-free tests: every provider is mocked, so no GCP or Twingate API is called.
# Run: terraform init -backend=false && terraform test

mock_provider "google" {
  mock_data "google_compute_zones" {
    defaults = {
      names = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email  = "tg-tf-demo-gce-vm@example-project.iam.gserviceaccount.com"
      member = "serviceAccount:tg-tf-demo-gce-vm@example-project.iam.gserviceaccount.com"
    }
  }
}

mock_provider "twingate" {}

variables {
  gcp_project_id = "example-project"
  tg_network     = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(google_compute_instance.connector) == 2
    error_message = "Expected two Connector VMs by default."
  }

  assert {
    condition     = alltrue([for i in google_compute_instance.connector : length(i.network_interface[0].access_config) == 0])
    error_message = "Connector VMs must not have external IPs."
  }

  assert {
    condition     = length(google_compute_instance.private_resource.network_interface[0].access_config) == 0
    error_message = "The private resource must not have an external IP."
  }

  assert {
    condition     = length(distinct(google_compute_instance.connector[*].zone)) == 2
    error_message = "Connectors must be spread across zones."
  }

  assert {
    condition = (
      google_compute_router_nat.this.enable_endpoint_independent_mapping == true &&
      google_compute_router_nat.this.enable_dynamic_port_allocation == false
    )
    error_message = "Cloud NAT must use endpoint-independent mapping (with static port allocation) for P2P."
  }

  assert {
    condition     = alltrue([for i in google_compute_instance.connector : i.shielded_instance_config[0].enable_secure_boot && i.metadata["enable-oslogin"] == "TRUE"])
    error_message = "Connector VMs must use Shielded VM secure boot and OS Login."
  }

  assert {
    condition     = google_compute_firewall.allow_internal.source_ranges == toset(["10.40.0.0/16"])
    error_message = "Ingress must be limited to the VPC address plan."
  }

  # A CRLF checkout would break the bash startup scripts
  assert {
    condition     = !strcontains(google_compute_instance.private_resource.metadata_startup_script, "\r")
    error_message = "Startup scripts must not contain carriage returns (check .gitattributes eol=lf)."
  }

  assert {
    condition     = twingate_remote_network.this.location == "GOOGLE_CLOUD"
    error_message = "Remote network location must be GOOGLE_CLOUD."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-gce.tg-tf-demo.int"
    error_message = "Resource address should be web-gce.<zone> without the trailing dot."
  }

  assert {
    condition     = length(twingate_service_account.this) == 0
    error_message = "Service account must be off by default."
  }

  assert {
    condition     = length(data.twingate_security_policy.this) == 0
    error_message = "No security policy lookup when tg_security_policy_name is null."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    gcp_zone_count            = 3
    tg_connector_count        = 3
    tg_security_policy_name   = "Example Policy"
    tg_create_service_account = true
    tg_existing_group_ids     = ["R3JvdXA6MQ==", "R3JvdXA6Mg=="]
  }

  assert {
    condition     = length(twingate_connector_tokens.this) == 3 && length(google_compute_instance.connector) == 3
    error_message = "Expected one token pair and one VM per Connector."
  }

  assert {
    condition     = length(distinct(google_compute_instance.connector[*].zone)) == 3
    error_message = "Three Connectors across three zones expected."
  }

  assert {
    condition = alltrue([
      for i, vm in google_compute_instance.connector :
      nonsensitive(strcontains(vm.metadata_startup_script, "binaries.twingate.com/connector/setup.sh") &&
      strcontains(vm.metadata_startup_script, twingate_connector_tokens.this[i].access_token))
    ])
    error_message = "Each Connector VM must install with its own token pair."
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

run "rejects_invalid_app_name" {
  command = plan

  variables {
    app_name = "Not_Valid"
  }

  expect_failures = [var.app_name]
}
