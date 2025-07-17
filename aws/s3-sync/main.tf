locals {
  oidc_url    = "https://${var.tenant_slug}.twingate.com/oidc"
  oidc_prefix = "${var.tenant_slug}.twingate.com/oidc"
  bucket_arn  = "arn:aws:s3:::${var.bucket_name}"
}

# OIDC provider: allows AWS to validate tokens issued by Twingate
resource "aws_iam_openid_connect_provider" "twingate" {
  url            = local.oidc_url
  client_id_list = [var.tenant_slug]
  # thumbprint_list can be added if using self-signed certs
}

# IAM policy assigned to the role: grants Twingate permission to upload logs
resource "aws_iam_policy" "twingate_s3_sync" {
  name        = "${var.tenant_slug}-twingate-s3-sync"
  description = "Allows Twingate to upload logs to S3"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "TwingateS3Sync"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${local.bucket_arn}/*"]
      }
    ]
  })
}

# IAM role assumed by Twingate via OIDC for secure log sync
resource "aws_iam_role" "twingate_s3_sync" {
  name = "${var.tenant_slug}-twingate-s3-sync-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.twingate.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_prefix}:aud" = var.tenant_slug
          "${local.oidc_prefix}:sub" = "events_sync"
        }
      }
    }]
  })
}

# Attach above policy to the IAM role
resource "aws_iam_role_policy_attachment" "twingate_attach" {
  role       = aws_iam_role.twingate_s3_sync.name
  policy_arn = aws_iam_policy.twingate_s3_sync.arn
}

# Create or manage the S3 bucket for log storage
resource "aws_s3_bucket" "logs" {
  bucket = var.bucket_name
}

# Bucket policy: grants only the sync role permission to put objects
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "TwingateS3Sync"
      Effect   = "Allow"
      Principal = {
        AWS = aws_iam_role.twingate_s3_sync.arn
      }
      Action   = ["s3:PutObject"]
      Resource = ["${aws_s3_bucket.logs.arn}/*"]
    }]
  })
}
