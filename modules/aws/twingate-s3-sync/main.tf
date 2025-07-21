locals {
  oidc_url    = "https://${var.tenant_slug}.twingate.com/oidc"
  oidc_prefix = "${var.tenant_slug}.twingate.com/oidc"
  bucket_arn  = "arn:aws:s3:::${var.bucket_name}"
}

#####################################################################
# Option A: OIDC-based integration (recommended)
#####################################################################

# OIDC provider to validate tokens from Twingate
resource "aws_iam_openid_connect_provider" "twingate" {
  url            = local.oidc_url
  client_id_list = [var.tenant_slug]
  tags           = var.tags
}

# IAM role for Twingate to assume
resource "aws_iam_role" "sync_role" {
  count = var.auth_method == "oidc" ? 1 : 0
  name  = "${var.tenant_slug}-twingate-sync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.twingate.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_prefix}:aud" = var.tenant_slug
          "${local.oidc_prefix}:sub" = "events_sync"
        }
      }
    }]
  })

  tags = var.tags
}

#####################################################################
# Option B: IAM user approach
#####################################################################


#####################################################################
# aasdfasdf
#####################################################################

# IAM policy to allow uploads (and optionally KMS)
resource "aws_iam_policy" "sync_policy" {
  name        = "${var.tenant_slug}-twingate-sync"
  description = "Allows Twingate to upload logs to S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = compact([
      {
        Sid      = "TwingateS3Sync",
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = ["${local.bucket_arn}/*"],
      },
      length(var.kms_key_arn) > 0 ? {
        Sid      = "TwingateS3SyncAllowKMS",
        Effect   = "Allow",
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"],
        Resource = var.kms_key_arn,
      } : null
    ])
  })
  tags = var.tags
}

# Attach policy to role
resource "aws_iam_policy_attachment" "sync_attach_oidc" {
  name       = "${var.tenant_slug}-twingate-sync-attach-oidc"
  count      = var.auth_method == "oidc" ? 1 : 0
  policy_arn = aws_iam_policy.sync_policy.arn
  roles      = [aws_iam_role.oidc_role[0].name]
}
resource "aws_iam_policy_attachment" "sync_attach_iam_user" {
  name       = "${var.tenant_slug}-twingate-sync-attach-iam-user"
  count      = var.auth_method == "iam_user" ? 1 : 0
  policy_arn = aws_iam_policy.sync_policy.arn
  users      = [aws_iam_user.iam_user[0].name]
}

# Optionally create the S3 bucket
resource "aws_s3_bucket" "logs" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.bucket_name
  tags   = var.tags
}

# Create bucket policy to allow only our role to upload
resource "aws_s3_bucket_policy" "logs_policy" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPut",
      Effect    = "Allow",
      Principal = var.auth_method == "oidc" ? { AWS = aws_iam_role.oidc_role[0].arn } : { AWS = aws_iam_user.iam_user[0].arn },
      Action    = ["s3:PutObject"],
      Resource  = ["${local.bucket_arn}/*"]
    }]
  })
}
