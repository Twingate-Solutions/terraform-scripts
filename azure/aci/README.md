# Twingate on Azure Container Instances

Deploys Twingate Connectors as Azure Container Instances in a VNet and a private nginx container reachable only through Twingate.

## Deploys

- Resource group, VNet, private subnet delegated to `Microsoft.ContainerInstance/containerGroups` (default outbound access disabled), NSG (Azure default rules only)
- Azure NAT Gateway + Standard public IP for private-subnet egress
- One container group per Connector (`tg_connector_count`), private IP only, image `tg_connector_image`, tokens via `secure_environment_variables`
- nginx container group (`mcr.microsoft.com/azurelinux/base/nginx:1`) with a private IP
- Azure Private DNS zone linked to the VNet, with an A record `web-aci.<zone>` for the nginx container group
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 80, ICMP)
- Optional: Docker Hub credentials for Connector image pulls, Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- Azure CLI signed in (`az login`), or `ARM_*` environment variables for a service principal / managed identity
- Resource providers registered in the subscription (azurerm 5.x no longer registers them): `Microsoft.Network`, `Microsoft.ContainerInstance`
- Twingate API token with Read, Write & Provision
- Recommended: Docker Hub account + personal access token (avoids anonymous pull rate limits)

## Usage

```sh
az login
az account set --subscription "<subscription-id>"   # or set azure_subscription_id / ARM_SUBSCRIPTION_ID
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerInstance

cp terraform.tfvars.example terraform.tfvars   # set tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
export TF_VAR_azure_aci_registry_password="<docker-hub-pat>"   # optional, with azure_aci_registry_username
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-aci.tg-tf-demo.int
```

Connector logs:

```sh
az container logs --resource-group tg-tf-demo-azure-aci-rg --name tg-tf-demo-connector-1
```

Teardown:

```sh
terraform destroy
# If the delegated subnet fails to delete (ACI service association link still clearing), wait a minute and re-run:
terraform destroy
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `tg_network` | — (required) | Twingate network slug (`<slug>.twingate.com`) |
| `tg_api_token` | `null` | API token; null reads `TWINGATE_API_TOKEN` |
| `tg_connector_count` | `2` | Connectors to deploy (one container group each) |
| `tg_connector_image` | `twingate/connector:1` | Connector image |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `azure_subscription_id` | `null` | Subscription; null = `ARM_SUBSCRIPTION_ID`, then the az CLI default |
| `azure_location` | `eastus` | Region |
| `azure_vnet_cidr_block` | `10.44.0.0/16` | VNet address space |
| `azure_aci_connector_cpu` / `azure_aci_connector_memory` | `1` / `2` | vCPU / GB per Connector |
| `azure_aci_registry_username` | `null` | Docker Hub username for authenticated pulls |
| `azure_aci_registry_password` | `null` | Docker Hub password or PAT (sensitive) |
| `azure_dns_zone_name` | `tg-tf-demo.int` | Private DNS zone |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_container_group_names` | Container groups running the Connectors |
| `private_resource_ip` | Private IP of the nginx container group |
| `nat_public_ip` | NAT gateway egress IP |
| `resource_group_name` | Resource group (`<app_name>-azure-aci-rg`) |
| `vnet_id` | VNet ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **NAT / P2P:** Azure NAT Gateway picks a random SNAT port for each new connection ([SNAT with Azure NAT Gateway](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-snat)), which is endpoint-dependent mapping. Twingate peer-to-peer needs endpoint-independent NAT on the Connector side ([P2P troubleshooting](https://www.twingate.com/docs/troubleshooting-p2p)), so Connectors behind it are expected to fall back to Relay. Traffic stays end-to-end encrypted; Relay adds latency, not risk. VNet-injected container groups cannot take a public IP, so ACI has no P2P-capable variant here; use `azure/vm` with a NIC public IP if P2P matters.
- **One container group per Connector:** each token pair runs in one place only. Container group changes force replacement (destroy, then create), so a redeploy briefly takes that Connector offline; the other Connector(s) carry traffic.
- **Tokens:** passed as `secure_environment_variables` (not returned by the ACI API or shown in the portal) and stored in Terraform state. Restrict state access.
- **Docker Hub rate limits:** anonymous pulls of `twingate/connector` from shared Azure egress IPs can fail deploys and restarts with `RegistryErrorResponse` from `index.docker.io`. Set `azure_aci_registry_username` / `azure_aci_registry_password` (PAT for SSO accounts) to authenticate. The nginx image comes from MCR and is unaffected.
- **Placeholder port:** ACI requires at least one port on a private-IP container group. Connector groups declare UDP 9999 with nothing listening on it, matching Twingate's Azure Terraform guide; Connectors accept no inbound connections.
- **DNS:** container groups use Azure-provided DNS, which resolves Private DNS zones linked to the VNet. If the VNet is switched to custom DNS servers, add a `dns_config` block; ACI does not inherit VNet custom DNS.
- **Destroy:** deleting the container groups leaves an ACI service association link on the delegated subnet that Azure removes asynchronously. `terraform destroy` can fail on the subnet (or the NAT gateway / NSG association) while it clears; wait about a minute and run `terraform destroy` again.
- **Zones:** container groups are not pinned to availability zones; HA comes from multiple Connectors.
- **Coexistence:** resource group name includes the deployment (`tg-tf-demo-azure-aci-rg`), so `azure/*` modules can share a subscription.
- **Cost:** 2× ACI 1 vCPU / 2 GB, 1× ACI 0.5 vCPU / 0.5 GB, NAT gateway (hourly + data processed), 1 Standard public IP, Private DNS zone.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate azure/aci
```
