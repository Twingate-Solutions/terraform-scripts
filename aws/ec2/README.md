# Twingate on AWS EC2

Deploys Twingate Connectors on EC2 and a private web server reachable only through Twingate.

## Deploys

- VPC with public and private subnets across `aws_az_count` AZs, internet gateway, route tables
- [fck-nat](https://fck-nat.dev/) instance as the private-subnet NAT (P2P friendly)
- `tg_connector_count` EC2 Connector instances (Twingate AMI), private subnets by default, spread across AZs
- Ubuntu 26.04 LTS instance running Apache in a private subnet
- Route 53 private hosted zone with an A record for the private instance (`web-ec2.<zone>`)
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 22/80, ICMP)
- Optional: VPC peering to an existing VPC, Twingate service account + key, security policy assignment

## Diagram

Diagrams show a single Connector; the module deploys `tg_connector_count` (default 2).

| Private subnet (default) | Public subnet |
| --- | --- |
| ![Private](./aws-ec2-cd-private.png) | ![Public](./aws-ec2-cd-public.png) |

## Prerequisites

- Terraform >= 1.9
- AWS credentials in the standard chain (env vars, `~/.aws` profile, or SSO)
- Twingate API token with Read, Write & Provision
- Optional: existing EC2 key pair (for SSH to the instances)

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # set tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-ec2.tg-tf-demo.int
ssh -i <key.pem> ubuntu@web-ec2.tg-tf-demo.int   # requires aws_ssh_key_pair
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
| `tg_connector_count` | `2` | Connectors to deploy |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `aws_region` | `us-east-1` | Region |
| `aws_vpc_cidr_block` | `10.37.0.0/16` | VPC CIDR |
| `aws_az_count` | `2` | AZs for subnets |
| `aws_connector_subnet_type` | `private` | `private` or `public` |
| `aws_connector_instance_type` | `t3a.micro` | Connector instance type |
| `aws_ssh_key_pair` | `null` | Existing key pair name |
| `aws_dns_zone_name` | `tg-tf-demo.int` | Private hosted zone; resource FQDN is `web-ec2.<zone>` |
| `enable_vpc_peering` | `false` | Peer with an existing same-account VPC |
| `peer_vpc_id`, `peer_vpc_cidr_block` | `null` | Required when peering is enabled |
| `peer_region` | `null` | Peer region; null = `aws_region` |
| `peer_route_table_id` | `null` | Peer route table for the return route; null = add it manually |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_instance_ids` | Connector EC2 instance IDs |
| `private_resource_ip` | Private IP of the Apache instance |
| `nat_public_ip` | fck-nat egress IP |
| `vpc_id` | VPC ID |
| `vpc_peering_connection_id` | Peering connection ID (null when disabled) |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **NAT / P2P:** the AWS managed NAT gateway does not support Twingate peer-to-peer. fck-nat does. See [Connector behind an incompatible NAT](https://www.twingate.com/docs/troubleshooting-p2p#what-to-do-if-your-connector-is-behind-an-incompatible-nat) if swapping in a managed NAT gateway.
- **Tokens:** Connector tokens are written to instance user data and Terraform state. Restrict access to both.
- **IMDSv2** is required on all instances; root volumes are encrypted.
- **AMIs:** looked up with `most_recent` but `ami` changes are ignored, so a new AMI release does not replace running instances. Pick one up explicitly: `terraform apply -replace='aws_instance.twingate_connector[0]'` (one Connector at a time), `-replace=aws_instance.private_resource`, `-replace=aws_instance.fck_nat`.
- **First boot:** the private resource retries the Apache install (up to 10 × 30 s) while fck-nat comes up or unattended-upgrades holds the dpkg lock.
- **VPC peering:** same account only. The peer route is added to both the public and private route tables, so Connectors reach the peer VPC in either subnet type. Without `peer_route_table_id`, add the return route (`aws_vpc_cidr_block` → peering connection) in the peer VPC manually. Add Twingate Resources for peer-VPC hosts separately.
- **Cost:** 2× t3a.micro, 1× t3.micro, 1× t4g.nano, public IPv4 for fck-nat, Route 53 hosted zone.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate aws/ec2
```
