# examples/ec2/outputs.tf

# =============================================================================
# PRIVATE CONNECTOR OUTPUTS
# =============================================================================

output "private_connector" {
  description = "Private EC2 connector information"
  value = {
    name                   = "${var.environment}-twingate-ec2-private"
    security_group_id      = module.twingate_ec2_private.security_group_id
    autoscaling_group_name = module.twingate_ec2_private.autoscaling_group_name
    autoscaling_group_arn  = module.twingate_ec2_private.autoscaling_group_arn
    iam_role_arn          = module.twingate_ec2_private.iam_role_arn
    iam_role_name         = module.twingate_ec2_private.iam_role_name
    launch_template_id    = module.twingate_ec2_private.launch_template_id
  }
}

# =============================================================================
# PUBLIC CONNECTOR OUTPUTS (If Created)
# =============================================================================

output "public_connector" {
  description = "Public EC2 connector information"
  value = var.create_public_connector ? {
    name                   = "${var.environment}-twingate-ec2-public"
    security_group_id      = module.twingate_ec2_public[0].security_group_id
    autoscaling_group_name = module.twingate_ec2_public[0].autoscaling_group_name
    autoscaling_group_arn  = module.twingate_ec2_public[0].autoscaling_group_arn
    iam_role_arn          = module.twingate_ec2_public[0].iam_role_arn
    iam_role_name         = module.twingate_ec2_public[0].iam_role_name
    launch_template_id    = module.twingate_ec2_public[0].launch_template_id
    elastic_ip            = module.twingate_ec2_public[0].elastic_ip
    elastic_ip_id         = module.twingate_ec2_public[0].elastic_ip_id
  } : null
}

# =============================================================================
# HIGH AVAILABILITY CONNECTOR OUTPUTS (If Created)
# =============================================================================

output "ha_connector" {
  description = "High Availability EC2 connector information"
  value = var.create_ha_connector ? {
    name                   = "${var.environment}-twingate-ec2-ha"
    security_group_id      = module.twingate_ec2_ha[0].security_group_id
    autoscaling_group_name = module.twingate_ec2_ha[0].autoscaling_group_name
    autoscaling_group_arn  = module.twingate_ec2_ha[0].autoscaling_group_arn
    iam_role_arn          = module.twingate_ec2_ha[0].iam_role_arn
    iam_role_name         = module.twingate_ec2_ha[0].iam_role_name
    launch_template_id    = module.twingate_ec2_ha[0].launch_template_id
  } : null
}

# =============================================================================
# SECURITY GROUP IDS (For Reference)
# =============================================================================

output "security_group_ids" {
  description = "All security group IDs created by the modules"
  value = compact([
    module.twingate_ec2_private.security_group_id,
    var.create_public_connector ? module.twingate_ec2_public[0].security_group_id : "",
    var.create_ha_connector ? module.twingate_ec2_ha[0].security_group_id : ""
  ])
}

# =============================================================================
# IAM ROLE ARNS (For Reference)
# =============================================================================

output "iam_role_arns" {
  description = "All IAM role ARNs created by the modules"
  value = compact([
    module.twingate_ec2_private.iam_role_arn,
    var.create_public_connector ? module.twingate_ec2_public[0].iam_role_arn : "",
    var.create_ha_connector ? module.twingate_ec2_ha[0].iam_role_arn : ""
  ])
}

# =============================================================================
# SUMMARY OUTPUT
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployed connectors"
  value = {
    environment = var.environment
    connectors = {
      private_connector = {
        deployed = true
        type     = "ec2-private"
        subnet   = "private"
      }
      public_connector = {
        deployed = var.create_public_connector
        type     = "ec2-public"
        subnet   = "public"
      }
      ha_connector = {
        deployed = var.create_ha_connector
        type     = "ec2-ha"
        subnet   = "private"
      }
    }
    total_connectors = 1 + (var.create_public_connector ? 1 : 0) + (var.create_ha_connector ? 1 : 0)
  }
}