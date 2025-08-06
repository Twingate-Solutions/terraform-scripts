# Data source or pull necessary ids from elsewhere
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

# Example 2 - SaaS App - Snowflake (more in-depth)
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