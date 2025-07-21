##############################################################
#
# Terraform providers
#
##############################################################

# Set required providers
terraform {
  required_providers {
    twingate = {
      source  = "twingate/twingate"
      version = "2.0.0"
    }
  }
}

# Configure Twingate Provider
provider "twingate" {
  api_token   = var.tg_api_token
  network     = var.tg_network
}

##############################################################
#
# Remote Network
#
##############################################################

resource "twingate_remote_network" "aws_network" {
    name = "aws_remote_network"
}




##############################################################
#
# Example 1 - You SCIM groups from an IdP to Twingate and want
#             to pull groups using a data source
#
##############################################################

data "twingate_groups" "all-groups" {
    # filters to be applied
    type = "SYNCED"
}

output "all-groups-ids" {
    value = [for group in data.twingate_groups.all-groups.groups : group.id]
}

resource "twingate_resource" "resource" {
    name = "network"
    address = "internal.int"
    remote_network_id = twingate_remote_network.aws_network.id

    access {
        group_ids = [for group in data.twingate_groups.all-groups.groups : group.id]
    }
}
##############################################################
#
# Example 2 - Hardcode group ids to a resource
#
##############################################################

resource "twingate_resource" "resource" {
    name = "network"
    address = "internal.int"
    remote_network_id = twingate_remote_network.aws_network.id

    access {
        group_ids = ["R3JvdXAXXXXXXX1", "R3JvdXAXXXXXXX2", "R3JvdXAXXXXXXX3", "R3JvdXAXXXXXXX4"]
    }
}

##############################################################
#
# Example 3 - Pull a list of groups from variables.tf &
#             store sensitive info in terraform.tfvars
#
##############################################################

resource "twingate_resource" "resource" {
    name = "network"
    address = "internal.int"
    remote_network_id = twingate_remote_network.aws_network.id

    access {
        group_ids = var.tg_group_ids
    }
}

##############################################################
#
# Example 4 - Add a list of users (by email) to a new
#             group in Twingate
#
##############################################################

# create users from list in variables.tf
resource "twingate_user" "tg_users_email" {
    for_each = toset(var.tg_users_email)
    email = "${each.value}"
    role = "MEMBER"
    send_invite = true
}

# (Optional) - output ids after user creation
output "tg_users_email_output" {
    value = values(twingate_user.tg_users_email)[*].id
}

# create a new group and add all the users in via their recently created ids
resource "twingate_group" "tg_users_email_group" {
    name = "GroupA"
    user_ids = values(twingate_user.tg_users_email)[*].id
}
