# Credential-free tests: the Twingate provider is mocked.

mock_provider "twingate" {}

# Note: mock_data/override_data cannot populate nested-attribute lists such as
# twingate_groups.groups (Terraform mock limitation), so Example 1 is checked for
# wiring only: the mocked lookup returns no groups.

variables {
  tg_network = "example"
}

run "defaults_create_no_users" {
  command = apply

  assert {
    condition     = length(twingate_user.by_email) == 0
    error_message = "No users should be created (and no invites sent) by default."
  }

  assert {
    condition     = length(twingate_resource.synced_groups.access_group) == length(data.twingate_groups.synced.groups)
    error_message = "Every synced group should get access."
  }
}

run "users_and_group_ids" {
  command = apply

  variables {
    tg_group_ids   = ["R3JvdXA6Mw==", "R3JvdXA6NA==", "R3JvdXA6NQ=="]
    tg_users_email = ["a@example.com", "b@example.com"]
  }

  assert {
    condition     = length(twingate_resource.group_ids.access_group) == 3
    error_message = "Each supplied group ID should get access."
  }

  assert {
    condition     = length(twingate_group.by_email.user_ids) == 2
    error_message = "Created users should be added to the group."
  }
}
