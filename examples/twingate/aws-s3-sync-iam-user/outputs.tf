output "twingate_s3_sync_access_key_id" {
  value       = aws_iam_access_key.twingate_s3_access_key.id
  description = "Access Key ID for Twingate S3 sync"
}

output "twingate_s3_sync_secret_access_key" {
  value       = aws_iam_access_key.twingate_s3_access_key.secret
  description = "Secret Access Key for Twingate S3 sync"
  sensitive   = true
}

output "twingate_s3_sync_bucket_name" {
  value       = var.aws_bucket_name
  description = "S3 bucket name (no ARN prefix)"
}

output "twingate_s3_sync_iam_user_name" {
  value       = aws_iam_user.twingate_s3_user.name
  description = "IAM user name for Twingate S3 sync"
}

output "twingate_s3_sync_iam_user_arn" {
  value       = aws_iam_user.twingate_s3_user.arn
  description = "IAM user ARN for Twingate S3 sync"
}