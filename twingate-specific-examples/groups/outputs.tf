output "synced_group_ids" {
  description = "Example 1: IDs of all SCIM-synced groups found"
  value       = data.twingate_groups.synced.groups[*].id
}

output "created_user_ids" {
  description = "Example 3: IDs of users created from tg_users_email"
  value       = [for u in twingate_user.by_email : u.id]
}

output "email_group_id" {
  description = "Example 3: ID of the group holding the created users"
  value       = twingate_group.by_email.id
}
