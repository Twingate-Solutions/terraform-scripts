variable "twingate_tenant_slug" {
  type        = string
  description = "Twingate network slug (e.g., acme)"
}

variable "aws_bucket_name" {
  type        = string
  description = "S3 bucket name for Twingate sync"
}