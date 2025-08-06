output "twingate_resources" {
  description = "Outputs the created Twingate resources"
  value = { for k, v in twingate_resource.this : k => {
    name       = v.name
    address    = v.address
    remote_network_id = v.remote_network_id
    security_policy_id = v.security_policy_id
    access_groups = v.access_group[*].group_id
    access_services = v.access_service[*].service_account_id
  }}
}
