##############################################################
#
# VM Service Account (logging & metrics only)
#
##############################################################

# Dedicated least-privilege identity instead of the Compute Engine default service account
resource "google_service_account" "vm" {
  account_id   = "${local.name_prefix}-vm"
  display_name = "${var.app_name} ${local.deployment} VMs"
}

resource "google_project_iam_member" "vm" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter"])

  project = var.gcp_project_id
  role    = each.value
  member  = google_service_account.vm.member
}

##############################################################
#
# Twingate Connector VMs (Debian 12, Twingate Linux installer)
#
##############################################################

locals {
  # GCE runs the startup script on every boot. The Twingate installer refuses to run when
  # connector.conf exists, so install once; on later boots systemd starts the Connector.
  # Retries cover Cloud NAT and package mirrors not being reachable yet on first boot.
  connector_startup_scripts = [
    for i in range(var.tg_connector_count) : <<-EOT
      #!/bin/bash
      set -uo pipefail
      CONF=/etc/twingate/connector.conf
      [ -f "$CONF" ] && exit 0

      for attempt in $(seq 1 10); do
        curl -fsSL https://binaries.twingate.com/connector/setup.sh | \
          TWINGATE_NETWORK="${var.tg_network}" \
          TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.this[i].access_token}" \
          TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.this[i].refresh_token}" \
          TWINGATE_LOG_ANALYTICS="${var.tg_log_analytics_version}" \
          bash && break
        echo "Twingate Connector install attempt $attempt failed; retrying in 30s"
        sleep 30
      done
      [ -f "$CONF" ] || exit 1

      # Settings the installer does not write
      {
        echo TWINGATE_LOG_LEVEL="${var.tg_log_level}"
        echo TWINGATE_LABEL_DEPLOYED_BY="terraform-gcp-gce"
      } >> "$CONF"
      systemctl restart twingate-connector
    EOT
  ]
}

# One VM per Connector, spread across zones, no external IP (egress via Cloud NAT)
resource "google_compute_instance" "connector" {
  count = var.tg_connector_count

  name                      = "${local.name_prefix}-connector-${count.index + 1}"
  description               = "Twingate Connector ${twingate_connector.this[count.index].name}"
  machine_type              = var.gcp_connector_machine_type
  zone                      = local.zones[count.index % length(local.zones)]
  tags                      = ["twingate-connector"]
  labels                    = local.common_labels
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  # Changing the script (e.g. new tokens) replaces the VM, like user_data_replace_on_change on AWS
  metadata_startup_script = local.connector_startup_scripts[count.index]

  # The Connector needs the NAT path in place before first boot
  depends_on = [google_compute_router_nat.this, google_project_iam_member.vm]
}

##############################################################
#
# Private Resource VM (nginx on Debian 12)
#
##############################################################

resource "google_compute_instance" "private_resource" {
  name                      = "${local.name_prefix}-private-resource"
  machine_type              = "e2-micro"
  zone                      = local.zones[0]
  tags                      = ["private-resource"]
  labels                    = local.common_labels
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    command -v nginx >/dev/null && exit 0
    for attempt in $(seq 1 10); do
      apt-get update && apt-get install -y nginx && break
      sleep 30
    done
  EOT

  depends_on = [google_compute_router_nat.this, google_project_iam_member.vm]
}

##############################################################
#
# Cloud DNS Private Zone (FQDN for the private resource)
#
##############################################################

resource "google_dns_managed_zone" "private" {
  name        = "${local.name_prefix}-private"
  dns_name    = "${var.gcp_dns_zone_name}."
  description = "Private zone for the ${var.app_name} Twingate demo"
  visibility  = "private"
  labels      = local.common_labels

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }
}

resource "google_dns_record_set" "private_resource" {
  managed_zone = google_dns_managed_zone.private.name
  name         = "web-gce.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.private_resource.network_interface[0].network_ip]
}
