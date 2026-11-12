##############################################################
#
# Remote Network & Connectors
#
##############################################################

resource "twingate_remote_network" "this" {
  name     = "${var.app_name} - ${local.deployment}"
  location = "AWS"
}

resource "twingate_connector" "this" {
  count = var.tg_connector_count

  remote_network_id = twingate_remote_network.this.id
}

# Tokens are stored in state (sensitive). Protect the state file.
resource "twingate_connector_tokens" "this" {
  count = var.tg_connector_count

  connector_id = twingate_connector.this[count.index].id
}

##############################################################
#
# Access: Group, (Optional) Service Account, (Optional) Policy
#
##############################################################

resource "twingate_group" "this" {
  name     = "${var.app_name} - ${local.deployment} Users"
  user_ids = var.tg_users
}

resource "twingate_service_account" "this" {
  count = var.tg_create_service_account ? 1 : 0

  name = "${var.app_name} - ${local.deployment}"
}

resource "twingate_service_account_key" "this" {
  count = var.tg_create_service_account ? 1 : 0

  name               = "${var.app_name} - ${local.deployment}"
  service_account_id = twingate_service_account.this[0].id
}

data "twingate_security_policy" "this" {
  count = var.tg_security_policy_name == null ? 0 : 1

  name = var.tg_security_policy_name
}

locals {
  # null = tenant Default Policy
  tg_security_policy_id = one(data.twingate_security_policy.this[*].id)
}

##############################################################
#
# Resource
#
##############################################################

resource "twingate_resource" "private_resource" {
  name = "${var.app_name} - ${local.deployment} Web"
  # In-cluster Service DNS name; resolved by the Connector pods via cluster DNS
  address            = "${kubernetes_service_v1.private_resource.metadata[0].name}.${kubernetes_service_v1.private_resource.metadata[0].namespace}.svc.cluster.local"
  remote_network_id  = twingate_remote_network.this.id
  security_policy_id = local.tg_security_policy_id

  # ClusterIP Services do not answer ICMP, so only TCP 80 is allowed
  protocols = {
    allow_icmp = false
    tcp = {
      policy = "RESTRICTED"
      ports  = ["80"]
    }
    udp = {
      policy = "DENY_ALL"
    }
  }

  # Demo group created above
  access_group {
    group_id           = twingate_group.this.id
    security_policy_id = local.tg_security_policy_id

    dynamic "access_policy" {
      for_each = var.tg_autolock_duration == null ? [] : [var.tg_autolock_duration]
      content {
        mode          = "AUTO_LOCK"
        approval_mode = "AUTOMATIC"
        duration      = access_policy.value
      }
    }
  }

  # Existing groups passed in by ID
  dynamic "access_group" {
    for_each = var.tg_existing_group_ids
    content {
      group_id           = access_group.value
      security_policy_id = local.tg_security_policy_id
    }
  }

  dynamic "access_service" {
    for_each = twingate_service_account.this[*].id
    content {
      service_account_id = access_service.value
    }
  }

  is_browser_shortcut_enabled = true
  is_visible                  = true
}
