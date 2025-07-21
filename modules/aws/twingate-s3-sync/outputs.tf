output "oidc_role_arn" {
  value       = var.auth_method == "oidc" && length(aws_iam_role.oidc_role) > 0 ? aws_iam_role.oidc_role[0].arn : ""
  description = "IAM role ARN for OIDC-based Twingate sync"
}

output "iam_user_credentials" {
  value = var.auth_method == "iam_user" && length(aws_iam_access_key.iam_user_key) > 0 ? {
    access_key = aws_iam_access_key.iam_user_key[0].id
    secret_key = aws_iam_access_key.iam_user_key[0].secret
  } : null
  sensitive   = true
  description = "Credentials for IAM user to use in legacy Twingate setup"
}
