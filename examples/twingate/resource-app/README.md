# Twingate Resource App Example: Snowflake

This example demonstrates how to configure **Twingate resources** for a **Snowflake deployment**  
using the `resource-app` Terraform module.

---

## 🚀 **Overview**

This example configures **multiple Snowflake resources** behind Twingate.  
It allows users to:

- Define **multiple resource addresses** (e.g., API, UI, staging, production).
- Configure **access control** (group-based and service accounts).
- Apply **security policies** and **protocol settings**.

---

## 📌 **Usage**

### **Example 1 - Basic SaaS App: Snowflake**

```hcl
module "twingate_resource_app_snowflake" {
  source            = "../../modules/resource-app"

  # Required fields
  name              = "app-snowflake"
  remote_network_id = "UmVtXXXXXXXXXXXXXXXX=="

  resources = [
    { address = "apps-api.c1.us-west-2.aws.app.snowflake.com" }, # Snowflake API
    { address = "app.snowflake.com" },                           # Snowflake UI
    { address = "hab04-staging.snowflakecomputing.com" },        # Staging
    { address = "ab40-prod.snowflakecomputing.com" }             # Production
  ]
}
```

---

### **Example 2 - Advanced Configuration with Groups & Security Policies**

#### **🔹 Retrieve Security Policies & Groups from Twingate**

```hcl
data "twingate_groups" "all" {
  name = "Everyone"
}

output "everyone_group" {
  value = data.twingate_groups.all.groups[0].id
}

data "twingate_security_policies" "all" {
  name = "TRUSTED-30DAY-NOMFA"
}

output "specific_policy" {
  value = data.twingate_security_policies.all.security_policies[0].id
}
```

#### **🔹 Configure Snowflake Resources with Access Control**

```hcl
module "twingate_resource_app_snowflake" {
  source            = "../../modules/resource-app"

  # Required fields
  name              = "app-snowflake"
  remote_network_id = "UmVXXXXXXXXXXXXXXXXXXXXXXX=="

  resources = [
    {
      address = "apps-api.c1.us-west-2.aws.app.snowflake.com"
      alias   = "us-snowflake-1.int"
    },
    {
      address = "app.snowflake.com"
      alias   = "us-snowflake-2.int"
    },
    {
      address = "hab04-staging.snowflakecomputing.com"
      alias   = "us-snowflake-3.int"
    },
    {
      address = "ab40-prod.snowflakecomputing.com"
      alias   = "us-snowflake-4.int"
    }
  ]

  # Optional fields
  is_browser_shortcut_enabled = false
  is_visible                  = true
  security_policy_id          = data.twingate_security_policies.all.security_policies[0].id

  protocols = {
    allow_icmp = true
    tcp = {
      policy = "RESTRICTED"
      ports  = ["80", "3000-3100"]
    }
    udp = {
      policy = "ALLOW_ALL"
    }
  }

  # Access Groups
  access_group = [
    { group_id = "R3JXXXXXXXXXXXXXXXXX" },                  # DevOps Team
    { group_id = data.twingate_groups.all.groups[0].id }    # Everyone
  ]

  # Service Accounts
  access_service = [
    { service_account_id = "U2VXXXXXXXXXXXX" }, # Service Account 1
    { service_account_id = "U2VXXXXXXXXXXXX" }  # Service Account 2
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
