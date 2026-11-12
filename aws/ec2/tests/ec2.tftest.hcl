# Credential-free tests: every provider is mocked, so no AWS or Twingate API is called.
# Run: terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

mock_provider "aws" {
  alias = "peer"
}

mock_provider "twingate" {}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(aws_instance.twingate_connector) == 2
    error_message = "Expected two Connector instances by default."
  }

  assert {
    condition     = alltrue([for i in aws_instance.twingate_connector : i.associate_public_ip_address == false])
    error_message = "Connectors must be in private subnets without public IPs by default."
  }

  assert {
    condition     = alltrue([for i in aws_instance.twingate_connector : i.metadata_options[0].http_tokens == "required"])
    error_message = "Connectors must require IMDSv2."
  }

  assert {
    condition = (
      length(aws_vpc_peering_connection.peer) == 0 && length(aws_route.from_peer) == 0 &&
      length(aws_route.to_peer) == 0 && length(aws_route.to_peer_public) == 0
    )
    error_message = "VPC peering must be off by default."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected public and private subnets in aws_az_count (2) AZs."
  }

  assert {
    condition     = length(twingate_service_account.this) == 0
    error_message = "Service account must be off by default."
  }

  assert {
    condition     = length(data.twingate_security_policy.this) == 0
    error_message = "No security policy lookup when tg_security_policy_name is null."
  }

  assert {
    condition     = aws_route53_record.private_resource.name == "web-ec2.tg-tf-demo.int"
    error_message = "Private resource record should be web-ec2.<zone>."
  }

  assert {
    condition = (
      strcontains(aws_instance.private_resource.user_data, "DPkg::Lock::Timeout") &&
      strcontains(aws_instance.private_resource.user_data, "seq 1 10")
    )
    error_message = "Private resource install must retry and wait for the dpkg lock."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    aws_connector_subnet_type = "public"
    tg_connector_count        = 3
    enable_vpc_peering        = true
    peer_vpc_id               = "vpc-0123456789abcdef0"
    peer_vpc_cidr_block       = "10.50.0.0/16"
    peer_route_table_id       = "rtb-0123456789abcdef0"
    tg_security_policy_name   = "Example Policy"
    tg_create_service_account = true
    tg_existing_group_ids     = ["R3JvdXA6MQ==", "R3JvdXA6Mg=="]
  }

  assert {
    condition     = length(twingate_connector_tokens.this) == 3
    error_message = "Expected one token pair per Connector."
  }

  assert {
    condition     = alltrue([for i in aws_instance.twingate_connector : i.associate_public_ip_address])
    error_message = "Public subnet mode must assign public IPs."
  }

  assert {
    condition = alltrue([
      for i, inst in aws_instance.twingate_connector : nonsensitive(
        strcontains(inst.user_data, "TWINGATE_ACCESS_TOKEN=\"${twingate_connector_tokens.this[i].access_token}\"") &&
        strcontains(inst.user_data, "TWINGATE_REFRESH_TOKEN=\"${twingate_connector_tokens.this[i].refresh_token}\"") &&
        !strcontains(inst.user_data, twingate_connector_tokens.this[(i + 1) % length(twingate_connector_tokens.this)].access_token)
      )
    ])
    error_message = "Each Connector instance must carry its own token pair and no other Connector's."
  }

  assert {
    condition     = length(aws_route.from_peer) == 1
    error_message = "Return route expected when peer_route_table_id is set."
  }

  # Connectors are in the public subnets in this run, so the public table needs the peer route
  assert {
    condition = (
      length(aws_route.to_peer_public) == 1 &&
      aws_route.to_peer_public[0].route_table_id == aws_route_table.public.id &&
      aws_route.to_peer_public[0].destination_cidr_block == "10.50.0.0/16"
    )
    error_message = "Public route table must route the peer CIDR over the peering connection."
  }

  assert {
    condition     = length(aws_route.to_peer) == 1 && aws_route.to_peer[0].route_table_id == aws_route_table.private.id
    error_message = "Private route table must route the peer CIDR over the peering connection."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_group) == 3
    error_message = "Expected demo group plus two existing groups."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }

  assert {
    condition     = length(data.twingate_security_policy.this) == 1
    error_message = "Security policy lookup expected when tg_security_policy_name is set."
  }
}

run "peering_requires_inputs" {
  command = plan

  variables {
    enable_vpc_peering = true
  }

  expect_failures = [aws_vpc_peering_connection.peer]
}

# Mocked region has 3 AZs
run "too_few_azs_rejected" {
  command = plan

  variables {
    aws_az_count = 4
  }

  expect_failures = [aws_vpc.this]
}
