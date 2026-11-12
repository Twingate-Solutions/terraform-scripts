# Twingate on GCP Compute Engine

Deploys Twingate Connectors on Compute Engine VMs and a private web server reachable only through Twingate.

## Deploys

- Custom-mode VPC with a private subnet in `gcp_region`, Cloud Router, Cloud NAT (endpoint-independent mapping, static egress IP)
- Firewall rule allowing ingress from the VPC address plan only
- `tg_connector_count` Debian 12 Connector VMs (Twingate Linux installer, systemd), no external IPs, spread across `gcp_zone_count` zones
- Debian 12 VM running nginx, no external IP
- Cloud DNS private zone with an A record `web-gce.<zone>` for the nginx VM
- Dedicated VM service account (logging and metrics roles only); Shielded VM and OS Login on every VM
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 22/80, ICMP)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- GCP credentials via Application Default Credentials: `gcloud auth application-default login` (or `GOOGLE_APPLICATION_CREDENTIALS`)
- Permissions on the project: Owner, or Compute Admin + DNS Administrator + Service Account Admin + Service Account User + Project IAM Admin
- APIs enabled (command below)
- Twingate API token with Read, Write & Provision

```sh
gcloud services enable compute.googleapis.com dns.googleapis.com iam.googleapis.com \
  cloudresourcemanager.googleapis.com --project <project-id>
```

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # set gcp_project_id and tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Connectors install on first boot and show as connected in the Admin Console a few minutes after apply.

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-gce.tg-tf-demo.int
# SSH via OS Login (needs roles/compute.osLogin and a registered key):
gcloud compute os-login ssh-keys add --key-file ~/.ssh/id_ed25519.pub
ssh <os-login-username>@web-gce.tg-tf-demo.int    # username: gcloud compute os-login describe-profile
```

Connector install output (startup script):

```sh
gcloud compute instances get-serial-port-output tg-tf-demo-gce-connector-1 --zone <zone>
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
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `app_name` | `tg-tf-demo` | Name prefix (lowercase, max 16 chars); GCP names get `-gce` appended |
| `gcp_region` | `us-central1` | Region |
| `gcp_zone_count` | `2` | Zones to spread Connectors across |
| `gcp_vpc_cidr_block` | `10.40.0.0/16` | VPC address plan |
| `gcp_nat_min_ports_per_vm` | `128` | Cloud NAT ports per VM |
| `gcp_connector_machine_type` | `e2-small` | Connector machine type |
| `gcp_dns_zone_name` | `tg-tf-demo.int` | Private zone; the resource FQDN is `web-gce.<zone>` |

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

- **NAT / P2P:** Cloud NAT runs with endpoint-independent mapping so Twingate peer-to-peer works. Google only allows EIM with static port allocation, so dynamic port allocation is off and `gcp_nat_min_ports_per_vm` ports are reserved per VM. Raise it if NAT logs show dropped packets from port exhaustion.
- **Tokens:** Connector tokens are embedded in the VM startup script (instance metadata, readable by anyone with `compute.instances.get` on the project) and in Terraform state. Restrict access to both. Changing the script replaces the VM.
- **Install:** the startup script runs Twingate's documented installer (`binaries.twingate.com/connector/setup.sh`) once, retrying while Cloud NAT comes up, then appends `TWINGATE_LOG_LEVEL` and `TWINGATE_LABEL_DEPLOYED_BY` to `/etc/twingate/connector.conf`. Later boots skip the install; systemd starts the Connector.
- **Upgrades:** the Connector is an apt package. Per Twingate's systemd upgrade guide: `sudo apt update && sudo apt install -yq twingate-connector && sudo systemctl restart twingate-connector`, one Connector at a time. Connector VMs have no shell path by default (see below), so re-creating a VM (`terraform apply -replace='google_compute_instance.connector[0]'`) also works: it installs the latest package on first boot with the same tokens.
- **Access to the VMs:** no external IPs and no IAP rule. Connectors are managed through serial output and re-creation; add an IAP SSH firewall rule (`35.235.240.0/20`, TCP 22) if you need shell access.
- **Disks:** encrypted at rest by default (Google-managed keys).
- **Cost:** 2× e2-small, 1× e2-micro, Cloud NAT gateway and data processing, 1 static external IP, Cloud DNS private zone, NAT error logging.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate gcp/gce
```
