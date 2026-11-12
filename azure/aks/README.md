# Twingate on Azure Kubernetes Service

Deploys an AKS cluster with Twingate Connectors installed by the Twingate Helm chart and a private nginx Service reachable only through Twingate.

> **Warning:** by default the AKS API server is public, local accounts are enabled, and Terraform state holds a long-lived cluster-admin client certificate. Protect state, set `azure_aks_api_authorized_ip_ranges`, and see [Notes](#notes) before applying.

## Deploys

- Resource group, VNet, private node subnet (default outbound access disabled), NSG (Azure default rules only)
- Azure NAT Gateway + Standard public IP; the cluster uses `outbound_type = "userAssignedNATGateway"`
- User-assigned identity for the cluster with Network Contributor on the node subnet, plus a 60 s `time_sleep` for role propagation before the cluster is created
- AKS cluster (Free tier, Azure CNI Overlay), system node pool of `azure_aks_node_count` nodes across `azure_zones`, private node IPs only; API server optionally restricted to `azure_aks_api_authorized_ip_ranges`
- One `helm_release` per Connector (`tg_connector_count`), named `twingate-connector-<n>`, from `https://twingate.github.io/helm-charts` chart `connector`, with preferred anti-affinity across zones and nodes
- nginx Deployment + ClusterIP Service `web-aks` in namespace `azure_aks_namespace`
- Twingate Remote Network, Connectors + tokens, group, Resource `web-aks.<namespace>.svc.cluster.local` (TCP 80)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- Azure CLI signed in (`az login`), or `ARM_*` environment variables for a service principal / managed identity
- Permission to create role assignments on the resource group (Owner, User Access Administrator, or Role Based Access Control Administrator), for the subnet Network Contributor grant
- Resource providers registered in the subscription (azurerm 5.x no longer registers them): `Microsoft.Network`, `Microsoft.Compute`, `Microsoft.ContainerService`, `Microsoft.ManagedIdentity`
- Twingate API token with Read, Write & Provision
- Optional: `kubectl` for inspecting the cluster

## Usage

```sh
az login
az account set --subscription "<subscription-id>"   # or set azure_subscription_id / ARM_SUBSCRIPTION_ID
for rp in Microsoft.Network Microsoft.Compute Microsoft.ContainerService Microsoft.ManagedIdentity; do
  az provider register --namespace "$rp"
done

cp terraform.tfvars.example terraform.tfvars   # set tg_network, adjust the rest
# Recommended: azure_aks_api_authorized_ip_ranges = ["<your-public-ip>/32"]   (curl -s https://api.ipify.org)
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-aks.tg-tf-demo.svc.cluster.local
```

Connector pods and logs:

```sh
$(terraform output -raw aks_get_credentials_command)
kubectl -n tg-tf-demo get pods
kubectl -n tg-tf-demo logs -l app.kubernetes.io/instance=twingate-connector-1
```

Teardown:

```sh
terraform destroy
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `tg_network` | — (required) | Twingate network slug (`<slug>.twingate.com`) |
| `tg_api_token` | `null` | API token; null reads `TWINGATE_API_TOKEN` |
| `tg_connector_count` | `2` | Connectors to deploy (one Helm release each) |
| `tg_connector_image` | `twingate/connector:1` | Connector image (`<repository>:<tag>`) |
| `tg_helm_chart_version` | `0.1.35` | Connector chart version; null = latest |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `tg_log_level` | `"3"` | `3`, `4`, `6` or `7` (chart: error, warning, info, debug) |
| `azure_subscription_id` | `null` | Subscription; null = `ARM_SUBSCRIPTION_ID`, then the az CLI default |
| `azure_location` | `eastus` | Region |
| `azure_vnet_cidr_block` | `10.45.0.0/16` | VNet address space |
| `azure_zones` | `["1","2","3"]` | Node pool zones; `[]` for regions without zones |
| `azure_aks_node_count` | `2` | System pool nodes |
| `azure_aks_node_vm_size` | `Standard_D2s_v5` | System pool VM size |
| `azure_aks_kubernetes_version` | `null` | Kubernetes version; null = AKS default |
| `azure_aks_namespace` | `tg-tf-demo` | Namespace for Connectors and nginx |
| `azure_aks_api_authorized_ip_ranges` | `[]` | CIDRs allowed to reach the API server; `[]` = unrestricted. Must include where Terraform runs; NAT egress IP added automatically |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_release_names` | Helm releases running the Connectors |
| `kubernetes_namespace` | Namespace for Connectors and nginx |
| `aks_cluster_name` | AKS cluster name |
| `aks_get_credentials_command` | `az aks get-credentials` command for kubectl |
| `nat_public_ip` | NAT gateway egress IP |
| `resource_group_name` | Resource group (`<app_name>-azure-aks-rg`) |
| `vnet_id` | VNet ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **NAT / P2P:** Azure NAT Gateway picks a random SNAT port for each new connection ([SNAT with Azure NAT Gateway](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-snat)), which is endpoint-dependent mapping. Twingate peer-to-peer needs endpoint-independent NAT on the Connector side ([P2P troubleshooting](https://www.twingate.com/docs/troubleshooting-p2p)), so Connectors behind it are expected to fall back to Relay. Traffic stays end-to-end encrypted; Relay adds latency, not risk.
- **One release per Connector:** each release is a single-replica Deployment with its own token pair. The chart's Deployment uses the default RollingUpdate strategy, so a pod-template change briefly runs the old and new pod with the same tokens until the old pod terminates.
- **Tokens:** passed with `set_sensitive`; the chart stores them in a Kubernetes Secret. They are also in Terraform state and the Helm release Secret. Restrict access to both.
- **Labels:** the chart hard-codes `TWINGATE_LABEL_DEPLOYED_BY=helm`, so these Connectors show `deployed_by = helm`. The module adds `TWINGATE_LABEL_TERRAFORM_MODULE=terraform-azure-aks` through the chart's `env` value to record where they came from.
- **Chart vs image:** upgrading the chart does not update the Connector image; the image uses the rolling `:1` tag with `pullPolicy: Always`, so a pod restart picks up the latest 1.x.
- **Cluster access (security):** by default the API server is public (reachable from any IP) and AKS local accounts are enabled, so Terraform can configure the kubernetes/helm providers from `kube_config`. Terraform state therefore contains a long-lived cluster-admin client certificate and key (`kube_config`, and `kube_admin_config` where AKS returns it); anyone with state read access has full control of the cluster.
  - Protect state: remote backend with encryption and tight access, never commit it.
  - Set `azure_aks_api_authorized_ip_ranges`. It must include the public IP where Terraform runs, or later applies cannot reach the cluster. The NAT gateway egress IP is added automatically (Microsoft recommends allowing the cluster egress IP). Rules take up to two minutes to propagate.
  - If state may have been exposed, rotate the cluster certificates with `az aks rotate-certs --resource-group <rg> --name <cluster>` (restarts nodes, causes downtime), then `terraform apply -refresh-only` to pick up the new credentials.
  - Production: Entra ID RBAC with `local_account_disabled = true`, and a private cluster or API Server VNet Integration.
- **Role propagation:** a 60 s `time_sleep` after the Network Contributor grant avoids a first-apply failure while the role assignment propagates.
- **Provider wiring:** kubernetes and helm providers are configured from the cluster created in the same apply. If the cluster is replaced, apply in two steps (`-target=azurerm_kubernetes_cluster.this`, then a full apply).
- **Identity:** a user-assigned identity is used because a bring-your-own subnet needs Network Contributor for the cluster identity before the cluster exists.
- **Coexistence:** resource group name includes the deployment (`tg-tf-demo-azure-aks-rg`); AKS also creates its own `MC_*` node resource group.
- **Cost:** AKS Free tier control plane, 2× Standard_D2s_v5 nodes + OS disks, NAT gateway (hourly + data processed), 1 Standard public IP.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate azure/aks
```
