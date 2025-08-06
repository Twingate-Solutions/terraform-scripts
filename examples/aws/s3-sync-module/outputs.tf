output "twingate_s3_sync_bucket_name" {
  description = "S3 bucket name (no ARN prefix)"
  value       = module.aws-twingate-s3-sync.bucket_name
}

output "twingate_s3_sync_bucket_arn" {
  description = "ARN of the log bucket"
  value       = "arn:aws:s3:::${module.aws-twingate-s3-sync.bucket_name}"
}

output "twingate_s3_sync_access_key_id" {
  description = "Access Key ID for IAM user authentication"
  value       = module.aws-twingate-s3-sync.access_key_id
}

output "twingate_s3_sync_secret_access_key" {
  description = "Secret Access Key for IAM user authentication"
  value       = module.aws-twingate-s3-sync.secret_access_key
  sensitive   = true
}

output "twingate_s3_sync_iam_user_name" {
  description = "IAM username provisioned for sync"
  value       = module.aws-twingate-s3-sync.iam_user_name
}

output "twingate_s3_sync_auth_identity_name" {
  description = "Name of the IAM user or IAM role used by Twingate to authenticate with AWS, based on the selected auth_method"
  value       = module.aws-twingate-s3-sync.iam_user_name != null ? module.aws-twingate-s3-sync.iam_user_name : module.aws-twingate-s3-sync.oidc_role_name
}

output "twingate_s3_sync_role_arn" {
  description = "IAM role ARN for Twingate OIDC integration"
  value       = module.aws-twingate-s3-sync.twingate_s3_sync_role_arn
}