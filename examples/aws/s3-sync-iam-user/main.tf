# Defining reusable values
locals {
  bucket_arn = "arn:aws:s3:::${var.aws_bucket_name}"
}

# IAM user for static access
resource "aws_iam_user" "twingate_s3_user" {
  name = "${var.twingate_tenant_slug}-s3-sync-user"
}

# IAM policy allowing S3 PutObject
resource "aws_iam_policy" "twingate_s3_policy" {
  name        = "${var.twingate_tenant_slug}-s3-sync-policy"
  description = "Allows PutObject to Twingate log bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TwingateIAMUserS3Sync"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = [
          local.bucket_arn,
          "${local.bucket_arn}/*"
        ]
      }
    ]
  })
}

# Attach the policy to the user
resource "aws_iam_user_policy_attachment" "twingate_user_attach" {
  user       = aws_iam_user.twingate_s3_user.name
  policy_arn = aws_iam_policy.twingate_s3_policy.arn
}

# Create access keys for the user
resource "aws_iam_access_key" "twingate_s3_access_key" {
  user = aws_iam_user.twingate_s3_user.name
}

# Create or manage the S3 bucket
resource "aws_s3_bucket" "logs" {
  bucket        = var.aws_bucket_name
  #force_destroy = true # Optional: allow bucket deletion without manual cleanup
}

# Optional: S3 bucket policy (if you want to restrict writes to this IAM user specifically)
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTwingateUserToPutObject",
        Effect    = "Allow",
        Principal = { AWS = aws_iam_user.twingate_s3_user.arn },
        Action    = ["s3:PutObject"],
        Resource  = "${local.bucket_arn}/*"
      }
    ]
  })
}