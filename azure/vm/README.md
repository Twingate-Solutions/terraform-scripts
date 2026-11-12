# Twingate on Azure VM

Deploys Twingate Connectors on Azure Linux VMs and a private web server reachable only through Twingate.

## Deploys

- Resource group, VNet, private subnet (default outbound access disabled), NSG (Azure default rules only)
- Azure NAT Gateway + Standard public IP for private-subnet egress
- `tg_connector_count` Ubuntu 24.04 Connector VMs, private IP only, spread across `azure_zones`, installed with Twingate's Linux setup script (systemd)
- Ubuntu 24.04 VM running nginx in the private subnet
- Azure Private DNS zone linked to the VNet, with an A record `web-vm.<zone>` for the nginx VM
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 22/80, ICMP)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- Azure CLI signed in (`az login`), or `ARM_*` environment variables for a service principal / managed identity
- Resource providers registered in the subscription (azurerm 5.x no longer registers them): `Microsoft.Network`, `Microsoft.Compute`
- Twingate API token with Read, Write & Provision
- Optional: SSH public key (for SSH to the VMs through Twingate)

## Usage

```sh
az login
az account set --subscription "<subscription-id>"   # or set azure_subscription_id / ARM_SUBSCRIPTION_ID
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute

cp terraform.tfvars.example terraform.tfvars   # set tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-vm.tg-tf-demo.int
ssh azureuser@web-vm.tg-tf-demo.int   # requires azure_ssh_public_key
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
| `tg_connector_count` | `2` | Connectors to deploy (one VM each) |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `azure_subscription_id` | `null` | Subscription; null = `ARM_SUBSCRIPTION_ID`, then the az CLI default |
| `azure_location` | `eastus` | Region |
| `azure_vnet_cidr_block` | `10.43.0.0/16` | VNet address space |
| `azure_zones` | `["1","2","3"]` | Zones for Connector VMs; `[]` for regions without zones |
| `azure_connector_vm_size` | `Standard_B2ats_v2` | Connector VM size |
| `azure_ssh_public_key` | `null` | Admin SSH public key; null = throwaway key, no SSH |
| `azure_dns_zone_name` | `tg-tf-demo.int` | Private DNS zone |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_vm_ids` | Connector VM IDs |
| `private_resource_ip` | Private IP of the nginx VM |
| `nat_public_ip` | NAT gateway egress IP |
| `resource_group_name` | Resource group (`<app_name>-azure-vm-rg`) |
| `vnet_id` | VNet ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **NAT / P2P:** Azure NAT Gateway picks a random SNAT port for each new connection ([SNAT with Azure NAT Gateway](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-snat)), which is endpoint-dependent mapping. Twingate peer-to-peer needs endpoint-independent NAT on the Connector side ([P2P troubleshooting](https://www.twingate.com/docs/troubleshooting-p2p)), so Connectors behind it are expected to fall back to Relay. Traffic stays end-to-end encrypted; Relay adds latency, not risk. A P2P-capable alternative is a Standard public IP on the Connector NIC (stateless 1:1 NAT, no SNAT per [Azure outbound connections](https://learn.microsoft.com/azure/load-balancer/load-balancer-outbound-connections)) in a subnet *without* a NAT gateway, since NAT Gateway takes precedence over instance public IPs. Not verified live.
- **Tokens:** Connector tokens are written to VM `custom_data`, `/etc/twingate/connector.conf` and Terraform state in plaintext. Restrict access to all three. A token change replaces the VM.
- **Install:** VMs fetch `https://binaries.twingate.com/connector/setup.sh` at first boot (needs the NAT path). Both the Connector and nginx installs run once via `custom_data` and retry up to 10 times, 30 s apart, waiting up to 300 s on dpkg locks. If the Connector config is still missing after the retries, the script exits non-zero: check `cloud-init status --long` and `/var/log/cloud-init-output.log` on the VM. Connector upgrades are via `apt` on the VM.
- **custom_data changes:** editing either boot script replaces the affected VMs (Azure cannot update `custom_data` in place).
- **SSH key:** Azure requires an admin credential. With `azure_ssh_public_key = null` a throwaway ED25519 key is generated (`tls_private_key`); the private half exists only in Terraform state and is not output. Password authentication is disabled.
- **Disks:** managed disks are encrypted at rest with platform-managed keys (Azure default).
- **NSG:** no custom rules. Azure defaults allow inbound from the VNet only and all outbound; Connectors need no inbound.
- **Coexistence:** resource group name includes the deployment (`tg-tf-demo-azure-vm-rg`), so `azure/*` modules can share a subscription.
- **Cost:** 3× Standard_B2ats_v2, 3× StandardSSD OS disks, NAT gateway (hourly + data processed), 1 Standard public IP, Private DNS zone.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate azure/vm
```
