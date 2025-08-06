# resource-app

This Terraform module creates and manages **Twingate resources** following a standardized structure.  
It is useful for defining a group of **resources** that share similar configurations or have multiple addresses:

- **Snowflake**
- **GitHub**
- **Jira**
- **Datadog**
- **Private resources**

---

## 🚀 **Features**

- Defines **multiple** Twingate resources at once that might share similar configurations.
- Supports **dynamic access control** via groups and service accounts.
- Allows **custom protocol settings** (TCP/UDP/ICMP).
- Configurable **visibility and security policies**.

---

## 📌 **Requirements**

| Name                                                                                  | Version |
| ------------------------------------------------------------------------------------- | ------- |
| [Terraform](https://developer.hashicorp.com/terraform/downloads)                      | >= 1.0  |
| [Twingate Provider](https://registry.terraform.io/providers/twingate/twingate/latest) | >= 3.0  |

---

## 🔧 **Usage Example**

**Basic:** Defining multiple resources under the same resource-app module.

```hcl
module "twingate_resource_app_snowflake" {
  source            = "../../modules/resource-app"

  # Required fields
  name              = "app-snowflake"
  remote_network_id = "UmVtXXXXXXXXXXXXXXXX=="
  resources = [
    {address        = "apps-api.c1.us-west-2.aws.app.snowflake.com"}, # snowflake apps
    {address        = "app.snowflake.com"},                           # snowsight
    {address        = "hab04-staging.snowflakecomputing.com"},        # staging
    {address        = "ab40-prod.snowflakecomputing.com"}             # production
  ]
}
```

**Advanced:** Specifying more resource settings to apply across all resources under the resource-app.

```hcl
module "twingate_resource_app_snowflake" {
  source = "../../modules/resource-app"

  # Required fields
  name               = "app-snowflake"
  remote_network_id  = "UmVXXXXXXXXXXXXXXXXXXXXXXX=="
  resources = [
    {
      address        = "apps-api.c1.us-west-2.aws.app.snowflake.com"
      alias          = "us-snowflake-1.int"
    },                                                              # snowflake apps
    {
      address        = "app.snowflake.com"
      alias          = "us-snowflake-1.int"
    },                                                              # snowsight
    {
      address        = "hab04-staging.snowflakecomputing.com"
      alias          = "us-snowflake-1.int"
    },                                                              # staging
    {
      address        = "ab40-prod.snowflakecomputing.com"
      alias          = "us-snowflake-1.int"
    }                                                               # production
  ]

  # Optional fields
  is_browser_shortcut_enabled = false
  is_visible                  = true
  security_policy_id          = data.twingate_security_policies.all.security_policies[0].id

  protocols = {
    allow_icmp = true
    tcp = {
      policy = "RESTRICTED"
      ports  = ["80","3000-3100"]
    }
    udp = {
      policy = "ALLOW_ALL"
    }
  }

  access_group = [
    { group_id = "R3JXXXXXXXXXXXXXXXXX" },                   # devops
    { group_id = data.twingate_groups.all.groups[0].id } # everyone
  ]

  access_service = [
    { service_account_id = "U2VXXXXXXXXXXXX" }, # service account 1
    { service_account_id = "U2VXXXXXXXXXXXX" }  # service account 2
  ]
}
```

## 📥 **Inputs**

| Name                          | Type           | Default | Required | Description                                                |
| ----------------------------- | -------------- | ------- | -------- | ---------------------------------------------------------- |
| `name`                        | `string`       | n/a     | ✅ Yes   | Prefix for resource names.                                 |
| `remote_network_id`           | `string`       | n/a     | ✅ Yes   | The ID of the remote network.                              |
| `resources`                   | `list(object)` | n/a     | ✅ Yes   | List of Twingate resource addresses with optional aliases. |
| `is_browser_shortcut_enabled` | `bool`         | `false` | ❌ No    | Enable or disable browser shortcut for the resources.      |
| `is_visible`                  | `bool`         | `true`  | ❌ No    | Whether the resource should be visible.                    |
| `security_policy_id`          | `string`       | `null`  | ❌ No    | The ID of the security policy to attach to the resource.   |
| `access_group`                | `list(object)` | `[]`    | ❌ No    | List of group access configurations.                       |
| `access_service`              | `list(object)` | `[]`    | ❌ No    | List of service account access configurations.             |
| `protocols`                   | `object`       | `{}`    | ❌ No    | Custom protocol settings, including TCP/UDP and ICMP.      |
