output "twingate_s3_sync_bucket_name" {
  value       = var.aws_bucket_name
  description = "S3 bucket name (no ARN prefix)"
}

output "twingate_s3_sync_role_name" {
  value       = aws_iam_role.twingate_s3_sync.name
  description = "The name of the IAM role Twingate assumes via OIDC (helpful for debugging)"
}

output "twingate_s3_sync_role_arn" {
  description = "IAM Role ARN that Twingate uses to upload logs"
  value       = aws_iam_role.twingate_s3_sync.arn
}