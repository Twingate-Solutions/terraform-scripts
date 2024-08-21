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

# Pull in an existing group from id
data "twingate_group" "tf_demo_eng" {
    id                        = var.tg_eng_group
}

# Pull in an existing group from filter
data "twingate_groups" "tf_demo_security" {
    name = "Security"
}

# Pull in an existing group from filter
data "twingate_groups" "tf_demo_it" {
    name = "IT"
}

# Create a demo group and add users to the group
resource "twingate_group" "tf_demo_admins" {
    name                        = "TF Demo - Admins"
    user_ids                    = var.tg_users
}

# Create a demo group and add users to the group
resource "twingate_group" "tf_demo_devops" {
    name                        = "TF Demo - Devops"
    user_ids                    = var.tg_users
}

##############################################################
#
# Security Policy
#
##############################################################

# Grab existing security policy
data "twingate_security_policy" "tf_demo_trusted-30day-nomfa" {
    name = "Trusted-30Day-noMFA"
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

    security_policy_id          = data.twingate_security_policy.tf_demo_trusted-30day-nomfa.id

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

    // Adding a single group via `access_group`
    access_group {
        group_id                           = twingate_group.tf_demo_admins.id                                 # Assign group to resource
        security_policy_id                 = data.twingate_security_policy.tf_demo_trusted-30day-nomfa.id     # Override default resource policy on group
        #usage_based_autolock_duration_days = 30                                                              # Set usage based autolock policy on group
    }

    // Adding multiple groups by individual ID
    dynamic "access_group" {
        for_each = toset([twingate_group.tf_demo_devops.id, data.twingate_group.tf_demo_eng.id])              # Loop over each group id
        content {
            group_id                           = access_group.value                                           # Assign groups to resource
            security_policy_id                 = data.twingate_security_policy.tf_demo_trusted-30day-nomfa.id # Override default resource policy on groups
            usage_based_autolock_duration_days = 30                                                           # Set usage based autolock policy on groups
        }
    }

    // Adding multiple groups from twingate_groups data sources
    dynamic "access_group" {
        for_each = setunion(
            data.twingate_groups.tf_demo_security.groups[*].id,
            data.twingate_groups.tf_demo_it.groups[*].id,
            // Single IDs can be added by wrapping them in a set
            toset([data.twingate_group.tf_demo_eng.id])
        )
        content {
            group_id                           = access_group.value                                           # Assign groups to resource
            security_policy_id                 = data.twingate_security_policy.tf_demo_trusted-30day-nomfa.id # Override default resource policy on groups
            usage_based_autolock_duration_days = 30                                                           # Set usage based autolock policy on groups
        }
    }

    // Service acoount access is specified similarly
    // A `for_each` block may be used like above to assign access to multiple 
    // service accounts in a single configuration block.
    access_service {
        service_account_id = twingate_service_account.tf_demo_service_account.id
    }

    alias                       = "tf-demo-aws.int"
    is_browser_shortcut_enabled = true
    is_visible                  = true
    is_active                   = true
    is_authoritative            = true
}
