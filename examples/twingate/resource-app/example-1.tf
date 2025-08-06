# Example 1 - SaaS App - Snowflake (basic)
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
