# Twingate on AWS ECS (Fargate)

Deploys Twingate Connectors as ECS Fargate services and a private nginx container reachable only through Twingate.

## Deploys

- VPC with public and private subnets across `aws_az_count` AZs, internet gateway, route tables
- [fck-nat](https://fck-nat.dev/) instance as the private-subnet NAT (P2P friendly)
- ECS cluster, CloudWatch log group, task execution role (`name_prefix`, so the module can run in several regions of one account)
- One Fargate service + task definition per Connector (`tg_connector_count`), spread across AZs
- Connector tokens in SSM Parameter Store (SecureString), injected as ECS secrets
- nginx Fargate service registered in a Cloud Map private DNS namespace (`web-ecs.<zone>`)
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 80, ICMP)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- AWS credentials in the standard chain (env vars, `~/.aws` profile, or SSO)
- Twingate API token with Read, Write & Provision

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # set tg_network, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-ecs.tg-tf-demo.int
```

Connector logs:

```sh
aws logs tail /ecs/tg-tf-demo --follow
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
| `tg_connector_count` | `2` | Connectors to deploy (one ECS service each) |
| `tg_connector_image` | `twingate/connector:1` | Connector image |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `aws_region` | `us-east-1` | Region |
| `aws_vpc_cidr_block` | `10.38.0.0/16` | VPC CIDR |
| `aws_az_count` | `2` | AZs for subnets |
| `aws_connector_subnet_type` | `private` | `private` or `public` (public assigns task public IPs) |
| `aws_connector_cpu` / `aws_connector_memory` | `1024` / `2048` | Fargate size per Connector |
| `aws_dns_zone_name` | `tg-tf-demo.int` | Cloud Map namespace; resource FQDN is `web-ecs.<zone>` |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `connector_names` | Twingate Connector names |
| `connector_service_names` | ECS services running the Connectors |
| `ecs_cluster_name` | ECS cluster name |
| `log_group_name` | CloudWatch log group |
| `nat_public_ip` | fck-nat egress IP |
| `vpc_id` | VPC ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **One task per Connector:** each token pair may run in one place only. Services use `desired_count = 1` and stop the old task before starting a replacement (`deployment_maximum_percent = 100`), so a redeploy briefly takes that Connector offline; the other Connector(s) carry traffic.
- **Token rotation:** tasks read the tokens from SSM only at start. Each Connector service has `force_new_deployment` plus a `triggers` hash of its own tokens, so replacing `twingate_connector_tokens` redeploys just that Connector.
- **NAT / P2P:** fck-nat is used because the AWS managed NAT gateway does not support Twingate peer-to-peer.
- **Tokens:** stored in SSM SecureString (AWS-managed key) and Terraform state. Restrict access to both.
- **fck-nat AMI:** looked up with `most_recent` but `ami` changes are ignored, so a new fck-nat release does not replace the NAT. Pick one up explicitly: `terraform apply -replace=aws_instance.fck_nat`.
- **Cost:** 2× Fargate 1 vCPU / 2 GB, 1× Fargate 0.25 vCPU, 1× t4g.nano, public IPv4 for fck-nat, Cloud Map namespace.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate aws/ecs
```
