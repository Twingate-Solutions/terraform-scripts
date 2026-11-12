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
      email  = "tg-tf-demo-cos-vm@example-project.iam.gserviceaccount.com"
      member = "serviceAccount:tg-tf-demo-cos-vm@example-project.iam.gserviceaccount.com"
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
    condition     = length(google_compute_instance.connector) == 2 && length(terraform_data.connector_user_data) == 2
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
    condition     = alltrue([for i in google_compute_instance.connector : i.boot_disk[0].initialize_params[0].image == "cos-cloud/cos-stable"])
    error_message = "Connectors must run on Container-Optimized OS."
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
    condition     = google_compute_firewall.allow_internal.source_ranges == toset(["10.41.0.0/16"])
    error_message = "Ingress must be limited to the VPC address plan."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-cos.tg-tf-demo.int"
    error_message = "Resource address should be web-cos.<zone> without the trailing dot."
  }

  assert {
    condition     = strcontains(local.private_resource_user_data, "nginx:stable-alpine") && startswith(local.private_resource_user_data, "#cloud-config\n")
    error_message = "Private resource must run nginx from a cloud-config payload."
  }

  # A CRLF checkout would put \r into the env file and unit files
  assert {
    condition     = !strcontains(local.connector_unit, "\r") && !strcontains(local.private_resource_user_data, "\r")
    error_message = "cloud-init payloads must not contain carriage returns (check .gitattributes eol=lf)."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    tg_connector_count        = 3
    tg_connector_image        = "twingate/connector:latest"
    tg_create_service_account = true
  }

  assert {
    condition     = length(twingate_connector_tokens.this) == 3 && length(google_compute_instance.connector) == 3
    error_message = "Expected one token pair and one VM per Connector."
  }

  # Deprecated konlet path must not be used
  assert {
    condition     = alltrue([for i in google_compute_instance.connector : !contains(keys(i.metadata), "gce-container-declaration")])
    error_message = "Connectors must not use gce-container-declaration (konlet)."
  }

  assert {
    condition = alltrue([
      for i, vm in google_compute_instance.connector : nonsensitive(
        startswith(vm.metadata["user-data"], "#cloud-config\n") &&
        strcontains(yamldecode(vm.metadata["user-data"]).write_files[0].content, "TWINGATE_ACCESS_TOKEN=${twingate_connector_tokens.this[i].access_token}") &&
        yamldecode(vm.metadata["user-data"]).write_files[0].permissions == "0600"
      )
    ])
    error_message = "Each Connector VM must get its own token pair in a 0600 env file."
  }

  assert {
    condition = alltrue([
      for vm in google_compute_instance.connector : nonsensitive(
        strcontains(yamldecode(vm.metadata["user-data"]).write_files[1].content, "--env-file /etc/twingate/connector.env twingate/connector:latest") &&
        contains(yamldecode(vm.metadata["user-data"]).runcmd, "systemctl start twingate-connector.service")
      )
    ])
    error_message = "Connector unit must run tg_connector_image with the env file and be started by runcmd."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }
}
