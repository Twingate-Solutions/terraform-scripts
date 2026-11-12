# Twingate group access examples

Twingate-only examples (no cloud resources) for granting group access to Resources.

## Deploys

- Remote Network `<name_prefix> - Network` (no Connectors; the Resources are illustrative)
- Example 1: Resource granted to every SCIM-synced group (`data "twingate_groups"` with `types = ["SYNCED"]`)
- Example 2: Resource granted to group IDs from `tg_group_ids`
- Example 3: users created from `tg_users_email`, added to a new group, group granted to a Resource

## Prerequisites

- Terraform >= 1.9
- Twingate API token with Read, Write & Provision

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars   # set tg_network
export TWINGATE_API_TOKEN="<token>"
terraform init
terraform apply
terraform destroy
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `tg_network` | — (required) | Twingate network slug |
| `tg_api_token` | `null` | API token; null reads `TWINGATE_API_TOKEN` |
| `name_prefix` | `TF Groups Example` | Prefix for created objects |
| `tg_group_ids` | `[]` | Example 2 group IDs |
| `tg_users_email` | `[]` | Example 3 user emails |

## Outputs

| Name | Description |
| --- | --- |
| `synced_group_ids` | IDs of SCIM-synced groups found |
| `created_user_ids` | IDs of users created |
| `email_group_id` | ID of the group holding created users |

## Notes

- Creating a `twingate_user` sends an invitation email. `tg_users_email` defaults to empty.
- Do not manage SCIM-synced groups with `resource "twingate_group"`; reference them with data sources (Example 1).
- One `access_group` block per group; use `dynamic "access_group"` for sets.

## Validate without credentials

```sh
docker compose -f ci/compose.yaml run --rm validate twingate-specific-examples/groups
```
