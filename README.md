# terraform-scripts

> ⚠️ **Example project — provided as-is, with no support or warranty.** terraform-scripts is published as a reference example to build from, not a supported product. Nothing here is guaranteed and no support is attached to it. It was developed with help from an LLM-based coding assistant. Review the code and test it yourself before using it in any critical or production environment. Your use is governed by the [Apache License 2.0](./LICENSE), including its "AS IS", no-warranty (Section 7), and limitation-of-liability (Section 8) terms.

Terraform quickstarts that deploy Twingate Connectors and a private demo resource on AWS, GCP, and Azure. Each folder is a standalone root module.

## Usage

```sh
cd <cloud>/<deployment>
cp terraform.tfvars.example terraform.tfvars   # set tg_network (+ gcp_project_id for gcp/*)
export TWINGATE_API_TOKEN="<token>"            # Read, Write & Provision
terraform init
terraform apply
terraform destroy
```

Requirements: Terraform >= 1.9, cloud CLI credentials, Twingate API token. Per-module prerequisites are in each README.

## Modules

| Cloud | VM | Container | Kubernetes |
| --- | --- | --- | --- |
| AWS | [aws/ec2](./aws/ec2/README.md) | [aws/ecs](./aws/ecs/README.md) | [aws/eks](./aws/eks/README.md) |
| GCP | [gcp/gce](./gcp/gce/README.md) | [gcp/gce-container](./gcp/gce-container/README.md) | [gcp/gke](./gcp/gke/README.md) |
| Azure | [azure/vm](./azure/vm/README.md) | [azure/aci](./azure/aci/README.md) | [azure/aks](./azure/aks/README.md) |

Twingate-only: [twingate-specific-examples/groups](./twingate-specific-examples/groups/README.md)

## Validation

Credential-free: `terraform fmt`, `validate`, `tflint`, and `terraform test` with mocked providers, in Docker.

```sh
docker compose -f ci/compose.yaml run --rm validate              # all modules
docker compose -f ci/compose.yaml run --rm validate aws/ec2      # one module
```

CI runs the same image on push and pull request: [.github/workflows/validate.yml](./.github/workflows/validate.yml).

Mocked tests check configuration, schema, and logic. They do not exercise cloud APIs; apply in a sandbox account before relying on a module.

## License

[Apache 2.0](./LICENSE)
