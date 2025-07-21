output "twingate_s3_sync_role_arn" {
  description = "IAM Role ARN that Twingate uses to upload logs"
  value       = aws_iam_role.twingate_s3_sync.arn
}
