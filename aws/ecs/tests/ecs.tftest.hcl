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

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_service_discovery_service" {
    defaults = {
      arn = "arn:aws:servicediscovery:us-east-1:123456789012:service/srv-mock"
    }
  }

  mock_resource "aws_ssm_parameter" {
    defaults = {
      arn = "arn:aws:ssm:us-east-1:123456789012:parameter/mock"
    }
  }
}

mock_provider "twingate" {}

# Distinct ARN per parameter, so task definition secrets can be traced to their own index
override_resource {
  target = aws_ssm_parameter.connector_access_token[0]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-1/access-token" }
}

override_resource {
  target = aws_ssm_parameter.connector_access_token[1]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-2/access-token" }
}

override_resource {
  target = aws_ssm_parameter.connector_access_token[2]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-3/access-token" }
}

override_resource {
  target = aws_ssm_parameter.connector_refresh_token[0]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-1/refresh-token" }
}

override_resource {
  target = aws_ssm_parameter.connector_refresh_token[1]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-2/refresh-token" }
}

override_resource {
  target = aws_ssm_parameter.connector_refresh_token[2]
  values = { arn = "arn:aws:ssm:us-east-1:123456789012:parameter/tg-tf-demo/twingate/connector-3/refresh-token" }
}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(aws_ecs_service.connector) == 2 && length(aws_ecs_task_definition.connector) == 2
    error_message = "Expected one task definition and one service per Connector."
  }

  assert {
    condition = alltrue([
      for s in aws_ecs_service.connector :
      s.desired_count == 1 && s.deployment_maximum_percent == 100 && s.deployment_minimum_healthy_percent == 0
    ])
    error_message = "Each Connector service must run exactly one task and stop it before starting a replacement."
  }

  assert {
    condition     = alltrue([for s in aws_ecs_service.connector : s.force_new_deployment == true])
    error_message = "Connector services must redeploy when their tokens rotate."
  }

  assert {
    condition = (
      length(distinct(concat(aws_ssm_parameter.connector_access_token[*].name, aws_ssm_parameter.connector_refresh_token[*].name))) == 4 &&
      aws_ssm_parameter.connector_access_token[1].name == "/tg-tf-demo/twingate/connector-2/access-token"
    )
    error_message = "Each Connector needs its own uniquely named token parameters."
  }

  assert {
    condition     = aws_service_discovery_service.private_resource.force_destroy == true
    error_message = "Cloud Map service must deregister leftover instances on destroy."
  }

  assert {
    condition     = startswith(aws_iam_role.task_execution.name_prefix, "tg-tf-demo-") && length(aws_iam_role.task_execution.name_prefix) <= 38
    error_message = "Execution role must use an IAM-valid name_prefix (<= 38 chars) so regions do not collide."
  }

  assert {
    condition     = alltrue([for s in aws_ecs_service.connector : s.network_configuration[0].assign_public_ip == false])
    error_message = "Connectors must not get public IPs by default."
  }

  assert {
    condition     = length(aws_ssm_parameter.connector_access_token) == 2 && alltrue([for p in aws_ssm_parameter.connector_access_token : p.type == "SecureString"])
    error_message = "Connector tokens must be stored as SecureString parameters."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-ecs.tg-tf-demo.int"
    error_message = "Resource address should be the Cloud Map FQDN web-ecs.<zone>."
  }
}

run "apply_mocked" {
  command = apply

  variables {
    tg_connector_count        = 3
    tg_create_service_account = true
  }

  assert {
    condition = (
      !contains([for e in jsondecode(aws_ecs_task_definition.connector[0].container_definitions)[0].environment : e.name], "TWINGATE_ACCESS_TOKEN") &&
      contains([for s in jsondecode(aws_ecs_task_definition.connector[0].container_definitions)[0].secrets : s.name], "TWINGATE_ACCESS_TOKEN")
    )
    error_message = "Access token must be injected via secrets, not plaintext environment."
  }

  assert {
    condition = alltrue([
      for i in range(3) : nonsensitive(
        aws_ssm_parameter.connector_access_token[i].value == twingate_connector_tokens.this[i].access_token &&
        aws_ssm_parameter.connector_refresh_token[i].value == twingate_connector_tokens.this[i].refresh_token
      )
    ])
    error_message = "Each Connector's SSM parameters must hold that Connector's own tokens."
  }

  assert {
    condition = alltrue([
      for i, td in aws_ecs_task_definition.connector :
      { for s in jsondecode(td.container_definitions)[0].secrets : s.name => s.valueFrom } == {
        TWINGATE_ACCESS_TOKEN  = aws_ssm_parameter.connector_access_token[i].arn
        TWINGATE_REFRESH_TOKEN = aws_ssm_parameter.connector_refresh_token[i].arn
      }
    ])
    error_message = "Each Connector task definition must reference its own index's token parameters."
  }

  assert {
    condition     = length(distinct([for td in aws_ecs_task_definition.connector : jsondecode(td.container_definitions)[0].secrets[0].valueFrom])) == 3
    error_message = "Connector task definitions must not share token parameters."
  }

  assert {
    condition = alltrue([
      for i, s in aws_ecs_service.connector : nonsensitive(
        s.triggers.connector_tokens == sha256("${twingate_connector_tokens.this[i].access_token}${twingate_connector_tokens.this[i].refresh_token}")
      )
    ])
    error_message = "Each Connector service's redeploy trigger must follow its own tokens."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }
}

# Mocked region has 3 AZs
run "too_few_azs_rejected" {
  command = plan

  variables {
    aws_az_count = 4
  }

  expect_failures = [aws_vpc.this]
}
