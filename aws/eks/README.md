# Twingate on AWS EKS

Deploys Twingate Connectors into an EKS cluster with the Twingate Helm chart and a private nginx Service reachable only through Twingate.

## Deploys

- VPC with public and private subnets across `aws_az_count` AZs (minimum 2), internet gateway, route tables
- [fck-nat](https://fck-nat.dev/) instance as the private-subnet NAT (P2P friendly)
- EKS cluster (access entries auth, public + private API endpoint), cluster IAM role (`name_prefix`)
- Managed node group in the private subnets (`aws_eks_node_count` × `aws_eks_node_instance_type`, AL2023, IMDSv2, encrypted root), node IAM role (`name_prefix`)
- Namespace `aws_eks_namespace`
- One `twingate/connector` Helm release per Connector (`twingate-connector-<n>`, image `tg_connector_image`), soft anti-affinity across zones
- nginx Deployment + ClusterIP Service (`web-eks.<namespace>.svc.cluster.local`)
- Twingate Remote Network, Connectors + tokens, group, Resource (TCP 80)
- Optional: Twingate service account + key, security policy assignment

## Prerequisites

- Terraform >= 1.9
- AWS credentials in the standard chain (env vars, `~/.aws` profile, or SSO)
- AWS CLI v2 on `PATH` (the helm/kubernetes providers authenticate with `aws eks get-token`)
- Twingate API token with Read, Write & Provision
- Optional: `kubectl`

## Usage

> **Warning:** the EKS API endpoint is public and `aws_eks_public_access_cidrs` defaults to `0.0.0.0/0` (the whole internet; access still needs valid IAM credentials). Set it to your egress IP/CIDR, e.g. `["203.0.113.10/32"]`. The CIDR must include the machine running Terraform, or the Helm/Kubernetes steps of the apply cannot reach the cluster.

```sh
cp terraform.tfvars.example terraform.tfvars   # set tg_network and aws_eks_public_access_cidrs, adjust the rest
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
```

Access (Twingate Client signed in, user in `tg_users`):

```sh
curl http://web-eks.twingate-demo.svc.cluster.local
```

kubectl (the identity that ran `terraform apply` is cluster admin):

```sh
$(terraform output -raw kubeconfig_command)
kubectl -n twingate-demo get pods
kubectl -n twingate-demo logs deploy/twingate-connector-1
```

Other IAM principals need an EKS access entry:

```sh
aws eks create-access-entry --cluster-name tg-tf-demo-eks --principal-arn <arn>
aws eks associate-access-policy --cluster-name tg-tf-demo-eks --principal-arn <arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
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
| `tg_helm_chart_version` | `0.1.35` | Twingate connector chart version |
| `tg_users` | `[]` | User IDs added to the demo group |
| `tg_existing_group_ids` | `[]` | Existing group IDs also granted access |
| `tg_security_policy_name` | `null` | Existing policy name; null = Default Policy |
| `tg_autolock_duration` | `"30d"` | Auto-lock access policy duration; null disables |
| `tg_create_service_account` | `false` | Create a service account + key with access |
| `tg_log_level` | `"3"` | `3` error, `4` warning, `6` info, `7` debug (chart-supported levels only) |
| `tg_log_analytics_version` | `"v2"` | `v1` or `v2` (chart-supported values only) |
| `aws_region` | `us-east-1` | Region |
| `aws_vpc_cidr_block` | `10.39.0.0/16` | VPC CIDR |
| `aws_az_count` | `2` | AZs for subnets (2–4) |
| `aws_eks_kubernetes_version` | `1.36` | EKS Kubernetes version |
| `aws_eks_node_instance_type` | `t3.small` | Node instance type |
| `aws_eks_node_count` | `2` | Nodes (fixed size) |
| `aws_eks_public_access_cidrs` | `["0.0.0.0/0"]` | CIDRs allowed to the public API endpoint. **Open to the internet by default:** set your egress IP/CIDR (must include where Terraform runs) |
| `aws_eks_namespace` | `twingate-demo` | Namespace for Connectors and the demo service |

Full list: [variables.tf](./variables.tf).

## Outputs

| Name | Description |
| --- | --- |
| `twingate_resource_address` | Address to use through the Twingate Client |
| `eks_cluster_name` | EKS cluster name |
| `kubeconfig_command` | `aws eks update-kubeconfig` command for this cluster |
| `kubernetes_namespace` | Namespace of the Connectors and demo service |
| `connector_names` | Twingate Connector names |
| `connector_release_names` | Helm releases running the Connectors |
| `nat_public_ip` | fck-nat egress IP |
| `vpc_id` | VPC ID |
| `service_account_key` | Service account key token (sensitive) |

## Notes

- **One release per Connector:** each token pair may run in one place only. The chart runs `replicas: 1` per release but does not expose the Deployment strategy, so on a values change Kubernetes' default rolling update (max surge 1, max unavailable 0) briefly runs the new and old pod on the same token pair until the new pod is Ready. Image updates (`twingate/connector:1`, `pullPolicy: Always`) happen on pod restart.
- **Resource address:** the in-cluster Service FQDN, resolved by the Connector pods through cluster DNS. Not resolvable outside the cluster without Twingate. ClusterIP does not answer ICMP, so only TCP 80 is allowed.
- **API endpoint:** public so Terraform can install the Helm releases. `aws_eks_public_access_cidrs` defaults to `0.0.0.0/0`; set it to your egress IP/CIDR, including wherever Terraform runs (CI runners too). A private-only endpoint needs Terraform to run inside the VPC.
- **Tokens:** passed with `set_sensitive`; the chart stores them in a Kubernetes Secret. They are also in the Helm release Secret and Terraform state. Restrict access to all three.
- **Network:** Connector pods use VPC CNI IPs on the nodes and the EKS cluster security group (egress all; inbound only from the cluster itself and the control plane).
- **NAT / P2P:** fck-nat is used because the AWS managed NAT gateway does not support Twingate peer-to-peer.
- **fck-nat AMI:** looked up with `most_recent` but `ami` changes are ignored, so a new fck-nat release does not replace the NAT. Pick one up explicitly: `terraform apply -replace=aws_instance.fck_nat`. Node AMIs are managed by the EKS node group (`ami_type`).
- **Support:** `upgrade_policy` is `STANDARD`: no extended-support charges; EKS auto-upgrades the control plane at end of standard support.
- **Single apply:** the cluster and the in-cluster resources are created in one apply. If a later change replaces the cluster, apply in two steps (`terraform apply -target=aws_eks_node_group.this`, then `terraform apply`).
- **Cost:** EKS control plane (hourly), 2× t3.small, 2× 20 GB gp3, 1× t4g.nano, public IPv4 for fck-nat.

## Validate without credentials

From the repo root:

```sh
docker compose -f ci/compose.yaml run --rm validate aws/eks
```
