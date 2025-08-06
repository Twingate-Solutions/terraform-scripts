resource "twingate_resource" "this" {
    for_each = { for idx, resource in var.resources : tostring(idx) => resource }
    
    # Required fields
    name                        = "${var.name}-${each.key}"
    address                     = each.value.address
    remote_network_id           = var.remote_network_id

    # Optional fields
    alias                       = each.value.alias
    is_active                   = var.is_active
    is_authoritative            = var.is_authoritative
    is_browser_shortcut_enabled = var.is_browser_shortcut_enabled
    is_visible                  = var.is_visible
    security_policy_id          = var.security_policy_id
    protocols = {
      allow_icmp = try(var.protocols.allow_icmp, true)
      tcp = {
        policy = try(var.protocols.tcp.policy, "ALLOW_ALL")
        ports  = try(var.protocols.tcp.ports, "")
      }
      udp = {
        policy = try(var.protocols.udp.policy, "ALLOW_ALL")
        ports  = try(var.protocols.udp.ports, "")
      }
    }


    # Group access => currently globally defined, future tbd on per resource basis (within resources for_each)
    dynamic "access_group" {
        for_each = var.access_group
        content {
          group_id                           = access_group.value.group_id
          #security_policy_id                 = access_group.value.security_policy_id
          #usage_based_autolock_duration_days = access_group.value.usage_based_autolock_duration_days
        }
    }

    # Service account access => currently globally defined, future tbd on per resource basis (within resources for_each)
    dynamic "access_service" {
      for_each = var.access_service
      content {
        service_account_id = access_service.value.service_account_id
      }
    }
}