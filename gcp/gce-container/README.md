# Twingate on GCP Compute Engine (Container-Optimized OS)

Deploys Twingate Connectors as `twingate/connector` containers on Container-Optimized OS VMs and a private nginx container reachable only through Twingate.

## Deploys

- Custom-mode VPC with a private subnet in `gcp_region`, Cloud Router, Cloud NAT (endpoint-independent mapping, static egress IP)
- Firewall rule allowing ingress from the VPC address plan only
- `tg_connector_count` COS VMs, one Connector container each, no external IPs, spread across `gcp_zone_count` zones
- Connector started by a systemd unit written by cloud-init `user-data` (`docker run`, host networking, `Restart=always`)
- COS VM running an nginx container, no external IP
- Cloud DNS private zone with an A record `web-cos.<zone>` for the nginx VM
- Dedicated VM service account (logging and metrics roles only); Shielded VM and OS Login on every VM
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 80, ICMP)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- GCP credentials via Application Default Credentials: `gcloud auth application-default login` (or `GOOGLE_APPLICATION_CREDENTIALS`)
- Permissions on the project: Owner, or Compute Admin + DNS Administrator + Service Account Admin + Service Account User + Project IAM Admin
- APIs enabled (command below)
- Twingate API token with Read, Write & Provision

```sh
gcloud services enable compute.googleapis.com dns.googleapis.com iam.googleapis.com \
  cloudresourcemanager.googleapis.com logging.googleapis.com --project <project-id>
```

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # set gcp_project_id and tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-cos.tg-tf-demo.int
```

Connector logs: Logs Explorer, resource type VM Instance, the Connector VM, systemd unit `twingate-connector.service` (COS ships its journal to Cloud Logging via `google-logging-enabled`). Boot and cloud-init output:

```sh
gcloud compute instances get-serial-port-output tg-tf-demo-cos-connector-1 --zone <zone>
```

Teardown:

```sh
terraform destroy
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `gcp_project_id` | — (required) | GCP project ID |
| `tg_network` | — (required) | Twingate network slug (`<slug>.twingate.com`) |
| `tg_api_token` | `null` | API token; null reads `TWINGATE_API_TOKEN` |
| `tg_connector_count` | `2` | Connectors to deploy (one VM each) |
| `tg_connector_image` | `twingate/connector:1` | Connector image |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `app_name` | `tg-tf-demo` | Name prefix (lowercase, max 16 chars); GCP names get `-cos` appended |
| `gcp_region` | `us-central1` | Region |
| `gcp_zone_count` | `2` | Zones to spread Connectors across |
| `gcp_vpc_cidr_block` | `10.41.0.0/16` | VPC address plan |
| `gcp_nat_min_ports_per_vm` | `128` | Cloud NAT ports per VM |
| `gcp_connector_machine_type` | `e2-small` | Connector machine type |
| `gcp_dns_zone_name` | `tg-tf-demo.int` | Private zone; the resource FQDN is `web-cos.<zone>` |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_instance_names` | Connector VM names |
| `connector_instance_zones` | Connector VM zones |
| `private_resource_ip` | Private IP of the nginx VM |
| `nat_public_ip` | Cloud NAT static egress IP |
| `vpc_id` | VPC network ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **No konlet:** the deprecated `gce-container-declaration` metadata is not used. COS re-runs cloud-init on every boot, rewriting the unit files and starting the containers.
- **NAT / P2P:** Cloud NAT runs with endpoint-independent mapping so Twingate peer-to-peer works. Google only allows EIM with static port allocation, so dynamic port allocation is off. The Connector uses host networking, so there is no Docker NAT layer in the path.
- **Tokens:** written to `/etc/twingate/connector.env` (mode 0600) from cloud-init `user-data`. The user-data sits in instance metadata (readable by anyone with `compute.instances.get` on the project) and in Terraform state. Restrict access to both. A change to user-data replaces the VM.
- **Upgrades:** the unit pulls `tg_connector_image` before each start, so restarting the service or the VM picks up a new release on the rolling `:1` tag. Restart one Connector at a time.
- **Docker Hub:** images pull through `mirror.gcr.io` when Google's cache holds them, else Docker Hub (rate limits apply per NAT IP).
- **ICMP:** `net.ipv4.ping_group_range` is opened on the host at boot so ping works through the Connector.
- **Cost:** 2× e2-small, 1× e2-micro, Cloud NAT gateway and data processing, 1 static external IP, Cloud DNS private zone, NAT error logging, Cloud Logging ingestion.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate gcp/gce-container
```
