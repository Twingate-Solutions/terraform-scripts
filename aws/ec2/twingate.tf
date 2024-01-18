##############################################################
#
# Remote Network
#
##############################################################

# Create a remote network
resource "twingate_remote_network" "tf_demo_aws_network" {
    name                        = "TF Demo - AWS Network"
    location                    = "AWS"
}

##############################################################
#
# Connectors
#
##############################################################

# Provision a new connector
resource "twingate_connector" "tf_demo_aws_connector" {
    remote_network_id           = twingate_remote_network.tf_demo_aws_network.id
}

# Generate auth tokens for new connector
resource "twingate_connector_tokens" "tf_demo_aws_connector_tokens" {
    connector_id                = twingate_connector.tf_demo_aws_connector.id
}

##############################################################
#
# Service Account (if applicable)
#
##############################################################

# (Optional) Provision a new service account
resource "twingate_service_account" "tf_demo_service_account" {
    name                        = "TF Demo - Service Account"
}

# (Optional) Generate a key for the new service account
resource "twingate_service_account_key" "tf_demo_service_account_key" {
    name                        = "TF Demo - Service Account Key"
    service_account_id          = twingate_service_account.tf_demo_service_account.id
}

##############################################################
#
# Group
#
##############################################################

# (Optional) Search for a specific existing group
data "twingate_groups" "everyone" {
    name                        = "Everyone"
}

# (Optional) Output array of result
output "available_everyone_groups" {
    value                       = data.twingate_groups.everyone.groups
}

# (Optional) Output 1st item of array => add to group_ids if you want to use (not included by default)
output "picked_everyone_group_id" {
    value                       = data.twingate_groups.everyone.groups[0].id
}

# Create a demo group and add users to the group
resource "twingate_group" "tf_demo_aws_group" {
    name                        = "TF Demo - AWS Group"
    user_ids                    = var.tg_users
}

##############################################################
#
# Security Policy
#
##############################################################

# Grab existing security policy
data "twingate_security_policy" "trusted-30day-nomfa" {
    name = "TRUSTED-30DAY-NOMFA"
}

##############################################################
#
# Resource
#
##############################################################

# Create a Twingate resource for our private instance we want to access via ssh or browser
resource "twingate_resource" "tf_demo_aws_resource" {
    name                        = "TF Demo - AWS Instance"
    address                     = aws_instance.private_resource.private_ip
    remote_network_id           = twingate_remote_network.tf_demo_aws_network.id

    security_policy_id          = data.twingate_security_policy.trusted-30day-nomfa

    protocols = {
        allow_icmp              = true
        tcp = {
            policy              = "RESTRICTED"
            ports               = ["22", "80"]
        }
        udp = {
            policy              = "ALLOW_ALL"
        }
    }

    access {
        group_ids               = [twingate_group.tf_demo_aws_group.id]
        service_account_ids     = [twingate_service_account.tf_demo_service_account.id]
    }

    alias                       = "tf-demo-aws.server"
    is_browser_shortcut_enabled = true
    is_visible                  = true
    is_active                   = true
    is_authoritative            = true
}
