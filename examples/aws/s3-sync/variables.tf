# The Twingate network slug, used for OIDC URL and audience
variable "tenant_slug" {
  type        = string
  description = "Twingate network slug (e.g., acme)"
}

# Name of the S3 bucket to receive logs
variable "bucket_name" {
  type        = string
  description = "S3 bucket name for Twingate sync"
}
