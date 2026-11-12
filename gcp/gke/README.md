# Twingate on GCP GKE

Deploys a GKE Standard cluster with private nodes, Twingate Connectors via the Twingate Helm chart, and an in-cluster nginx Service reachable only through Twingate.

## Deploys

- Custom-mode VPC with a private subnet in `gcp_region`, Cloud Router, Cloud NAT (endpoint-independent mapping, static egress IP)
- Firewall rule allowing ingress from the VPC address plan only
- GKE node subnet with Pod and Service secondary ranges
- Regional GKE Standard cluster: private nodes, public control plane endpoint (optionally restricted), Workload Identity, release channel
- Node pool of `gcp_gke_nodes_per_zone` × `gcp_zone_count` nodes (default 2), dedicated node service account, Shielded nodes
- One Helm release of the `twingate/connector` chart per Connector, spread across zones
- nginx Deployment + ClusterIP Service `web-gke` in namespace `gcp_gke_namespace`
- Twingate Remote Network, Connectors + tokens, group, Resource `web-gke.<namespace>.svc.cluster.local` (TCP 80)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- GCP credentials via Application Default Credentials: `gcloud auth application-default login` (or `GOOGLE_APPLICATION_CREDENTIALS`)
- Permissions on the project: Owner, or Kubernetes Engine Admin + Compute Admin + Service Account Admin + Service Account User + Project IAM Admin
- APIs enabled (command below)
- Twingate API token with Read, Write & Provision
- Optional: `kubectl` and `gke-gcloud-auth-plugin` to inspect the cluster (Terraform itself needs neither)

```sh
gcloud services enable container.googleapis.com compute.googleapis.com iam.googleapis.com \
  cloudresourcemanager.googleapis.com --project <project-id>
```

## Usage

> **Warning:** the GKE control-plane endpoint is public. With `gcp_gke_authorized_networks = []` (the default) it accepts connections from any IP address and only Google IAM protects it. Set `gcp_gke_authorized_networks` to your egress CIDR(s), e.g. `["203.0.113.10/32"]`. The list must include the address Terraform runs from, or the Helm and Kubernetes providers cannot reach the cluster.

```sh
cp terraform.tfvars.example terraform.tfvars   # set gcp_project_id and tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-gke.twingate-demo.svc.cluster.local
```

Connector logs:

```sh
$(terraform output -raw gke_get_credentials_command)
kubectl -n twingate-demo logs deploy/twingate-connector-1
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
| `tg_connector_count` | `2` | Connectors to deploy (one Helm release each) |
| `tg_connector_image` | `twingate/connector:1` | Connector image (`<repository>:<tag>`) |
| `tg_helm_chart_version` | `0.1.35` | Twingate connector chart version |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `tg_log_level` | `"3"` | `3`/`4`/`6`/`7`, mapped to the chart's error/warning/info/debug |
| `app_name` | `tg-tf-demo` | Name prefix (lowercase, max 16 chars); GCP names get `-gke` appended |
| `gcp_region` | `us-central1` | Region (regional cluster) |
| `gcp_zone_count` | `2` | Node zones |
| `gcp_vpc_cidr_block` | `10.42.0.0/16` | VPC address plan (nodes `.20.0/24`, Services `.32.0/20`, Pods `.64.0/18`) |
| `gcp_nat_min_ports_per_vm` | `256` | Cloud NAT ports per node |
| `gcp_gke_release_channel` | `REGULAR` | GKE release channel |
| `gcp_gke_machine_type` | `e2-medium` | Node machine type |
| `gcp_gke_nodes_per_zone` | `1` | Nodes per zone |
| `gcp_gke_authorized_networks` | `[]` | CIDRs allowed to reach the control plane; `[]` = open to any IP (see warning under Usage) |
| `gcp_gke_namespace` | `twingate-demo` | Namespace for Connectors and nginx |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_release_names` | Helm releases running the Connectors |
| `kubernetes_namespace` | Namespace for Connectors and nginx |
| `gke_cluster_name` | Cluster name |
| `gke_get_credentials_command` | `gcloud` command to configure kubectl |
| `nat_public_ip` | Cloud NAT static egress IP |
| `vpc_id` | VPC network ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **One release per Connector:** each token pair runs in one place only. The chart runs one replica per release. It does not expose the Deployment strategy, so a chart upgrade briefly overlaps the old and new pod. Upgrade one release at a time.
- **NAT / P2P:** Cloud NAT runs with endpoint-independent mapping and covers the Pod ranges, so Connector pods get P2P-friendly egress. Google only allows EIM with static port allocation, so dynamic port allocation is off. All pods on a node share `gcp_nat_min_ports_per_vm`.
- **Tokens:** passed with `set_sensitive`; the chart stores them in a Kubernetes Secret. They are also in Terraform state and the Helm release Secret. Restrict access to state and the namespace.
- **Cluster auth:** the Helm and Kubernetes providers use the cluster endpoint and the caller's short-lived Google OAuth token (`google_client_config`); no kubeconfig is read. The endpoint is public; with `gcp_gke_authorized_networks = []` it accepts connections from any IP. Set it to your egress CIDR(s), including the IP Terraform runs from.
- **Single apply:** the cluster and the Kubernetes objects are created in one run. If a plan fails on provider configuration after a partial apply, run `terraform apply -target=google_container_node_pool.this` and then `terraform apply`.
- **Connector image:** `tg_connector_image` (default `twingate/connector:1`) is split into the chart's `image.repository` and `image.tag`; the chart pulls with `pullPolicy: Always`, so `kubectl -n twingate-demo rollout restart deploy/twingate-connector-1` picks up a new release on the rolling `:1` tag. Upgrading the chart does not upgrade the image.
- **Labels:** the chart hard-codes `TWINGATE_LABEL_DEPLOYED_BY=helm`, so Connectors show `helm` as deployed-by. The module adds `TWINGATE_LABEL_TERRAFORM_MODULE=terraform-gcp-gke` through the chart's `env` value instead of a duplicate `DEPLOYED_BY` entry.
- **Destroy:** `deletion_protection = false` so `terraform destroy` removes the cluster.
- **Cost:** GKE cluster management fee (the free-tier credit covers one zonal or Autopilot cluster, not this regional cluster), 2× e2-medium nodes with 50 GB pd-balanced disks, Cloud NAT gateway and data processing, 1 static external IP, NAT error logging.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate gcp/gke
```
