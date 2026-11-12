##############################################################
#
# Remote Network (shared by the examples below)
#
##############################################################

resource "twingate_remote_network" "this" {
  name = "${var.name_prefix} - Network"
}

##############################################################
#
# Example 1 - Grant access to every group SCIM-synced from an
#             IdP, looked up with the twingate_groups data source
#
##############################################################

data "twingate_groups" "synced" {
  types = ["SYNCED"]
}

resource "twingate_resource" "synced_groups" {
  name              = "${var.name_prefix} - Synced Groups"
  address           = "synced.internal.int"
  remote_network_id = twingate_remote_network.this.id

  dynamic "access_group" {
    for_each = toset(data.twingate_groups.synced.groups[*].id)
    content {
      group_id = access_group.value
    }
  }
}

##############################################################
#
# Example 2 - Grant access to group IDs passed in as a variable
#             (set tg_group_ids in terraform.tfvars)
#
##############################################################

resource "twingate_resource" "group_ids" {
  name              = "${var.name_prefix} - Group IDs"
  address           = "ids.internal.int"
  remote_network_id = twingate_remote_network.this.id

  dynamic "access_group" {
    for_each = var.tg_group_ids
    content {
      group_id = access_group.value
    }
  }
}

##############################################################
#
# Example 3 - Create users by email, put them in a new group,
#             and grant that group access
#
# Creating a twingate_user sends the user an invitation email.
#
##############################################################

resource "twingate_user" "by_email" {
  for_each = var.tg_users_email

  email = each.value
  role  = "MEMBER"
}

resource "twingate_group" "by_email" {
  name     = "${var.name_prefix} - Email Users"
  user_ids = [for u in twingate_user.by_email : u.id]
}

resource "twingate_resource" "email_group" {
  name              = "${var.name_prefix} - Email Group"
  address           = "email.internal.int"
  remote_network_id = twingate_remote_network.this.id

  access_group {
    group_id = twingate_group.by_email.id
  }
}
