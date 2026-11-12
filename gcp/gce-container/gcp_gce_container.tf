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
# cloud-init (Container-Optimized OS)
#
##############################################################

# COS resets /etc on every boot and re-runs cloud-init, so the unit files are rewritten
# and the containers restarted by runcmd each boot. Units run `docker run` in the
# foreground under systemd (Restart=always); no gce-container-declaration / konlet.
locals {
  # Pull Docker Hub images through Google's cache when it has them (Docker Hub rate limits)
  docker_mirror_runcmd = [
    "echo 'DOCKER_OPTS=\"--registry-mirror=https://mirror.gcr.io\"' > /etc/default/docker",
    "systemctl daemon-reload",
    "systemctl restart docker",
  ]

  connector_unit = <<-EOT
    [Unit]
    Description=Twingate Connector
    Wants=network-online.target docker.service
    After=network-online.target docker.service

    [Service]
    Restart=always
    RestartSec=10
    ExecStartPre=-/usr/bin/docker rm -f twingate-connector
    # Re-pull so the rolling tag picks up new Connector releases on restart
    ExecStartPre=-/usr/bin/docker pull ${var.tg_connector_image}
    ExecStart=/usr/bin/docker run --rm --name twingate-connector --network host --env-file /etc/twingate/connector.env ${var.tg_connector_image}
    ExecStop=-/usr/bin/docker stop twingate-connector
  EOT

  connector_user_data = [
    for i in range(var.tg_connector_count) : "#cloud-config\n${yamlencode({
      write_files = [
        {
          path        = "/etc/twingate/connector.env"
          permissions = "0600"
          owner       = "root"
          content     = <<-EOT
            TWINGATE_NETWORK=${var.tg_network}
            TWINGATE_ACCESS_TOKEN=${twingate_connector_tokens.this[i].access_token}
            TWINGATE_REFRESH_TOKEN=${twingate_connector_tokens.this[i].refresh_token}
            TWINGATE_LOG_ANALYTICS=${var.tg_log_analytics_version}
            TWINGATE_LOG_LEVEL=${var.tg_log_level}
            TWINGATE_LABEL_DEPLOYED_BY=terraform-gcp-gce-container
          EOT
        },
        {
          path        = "/etc/systemd/system/twingate-connector.service"
          permissions = "0644"
          owner       = "root"
          content     = local.connector_unit
        },
      ]
      runcmd = concat(
        # Host network namespace: allow ICMP echo sockets for ping through the Connector
        ["sysctl -w net.ipv4.ping_group_range='0 2147483647'"],
        local.docker_mirror_runcmd,
        ["systemctl start twingate-connector.service"],
      )
    })}"
  ]

  private_resource_user_data = "#cloud-config\n${yamlencode({
    write_files = [
      {
        path        = "/etc/systemd/system/web.service"
        permissions = "0644"
        owner       = "root"
        content     = <<-EOT
          [Unit]
          Description=Demo nginx
          Wants=network-online.target docker.service
          After=network-online.target docker.service

          [Service]
          Restart=always
          RestartSec=10
          ExecStartPre=-/usr/bin/docker rm -f web
          # -p lets Docker open the COS host firewall for port 80
          ExecStart=/usr/bin/docker run --rm --name web -p 80:80 nginx:stable-alpine
          ExecStop=-/usr/bin/docker stop web
        EOT
      },
    ]
    runcmd = concat(local.docker_mirror_runcmd, ["systemctl start web.service"])
  })}"
}

##############################################################
#
# Twingate Connector VMs (COS, twingate/connector container)
#
##############################################################

# Instance metadata updates in place; this forces a new VM when the cloud-init payload
# (e.g. tokens) changes, like user_data_replace_on_change on AWS
resource "terraform_data" "connector_user_data" {
  count = var.tg_connector_count

  triggers_replace = sha256(local.connector_user_data[count.index])
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
      image = "cos-cloud/cos-stable"
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
    user-data              = local.connector_user_data[count.index]
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    google-logging-enabled = "true"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.connector_user_data[count.index]]
  }

  # The Connector needs the NAT path in place before first boot
  depends_on = [google_compute_router_nat.this, google_project_iam_member.vm]
}

##############################################################
#
# Private Resource VM (nginx container on COS)
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
      image = "cos-cloud/cos-stable"
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
    user-data              = local.private_resource_user_data
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    google-logging-enabled = "true"
  }

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
  name         = "web-cos.${google_dns_managed_zone.private.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.private_resource.network_interface[0].network_ip]
}
