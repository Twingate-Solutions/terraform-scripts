module "aws-twingate-s3-sync" {
  source = "../../../common/terraform/modules/aws/twingate-s3-sync"

  tenant_slug   = "twindemogb"
  bucket_name   = "test-twindemogb-logs"
  create_bucket = false  # or false
  auth_method   = "oidc" # or "iam_user"

  # Optional: provide this only if using SSE-KMS
  #kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/abcd1234-5678-90ef-ghij-1234567890ab"

  #tags = {
  #  keep        = "true"
  #  environment = "twindemo-ops"
  #  owner       = "soleng"
  #}
}