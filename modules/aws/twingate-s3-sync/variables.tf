# Twingate network slug (used in OIDC URL/audience)
variable "tenant_slug" {
  type        = string
  description = "Twingate network slug (e.g., acme)"
}

# Bucket name for logs; if using existing, ensure correct ownership
variable "bucket_name" {
  type        = string
  description = "Existing or new S3 bucket name for Twingate sync"
}

# Whether to create a new bucket
variable "create_bucket" {
  type        = bool
  description = "Set true to create a new bucket; false to use existing."
  default     = false
}

# Optional KMS key ARN for SSE-KMS encryption
variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN if bucket is encrypted (optional)"
  default     = ""
}

# Whether to use OIDC or IAM method for aws log sync
variable "auth_method" {
  type        = string
  default     = "oidc"
  description = "Authorization method: \"oidc\" or \"iam_user\""
}

# Specify name of IAM user if using IAM method
variable "iam_user_name" {
  type        = string
  default     = ""
  description = "Name for IAM user when using static IAM credentials"
}

# Tags to apply to resources
variable "tags" {
  type        = map(string)
  description = "Optional tags to apply"
  default     = {}
}
