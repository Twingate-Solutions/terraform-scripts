# AWS S3 Sync for Twingate (OIDC Role Example)

This is a standalone example using Terraform to provision an **S3 bucket and OIDC Role** that can be used with [Twingate’s AWS S3 Sync](https://www.twingate.com/docs/syncing-data-to-s3) to ingest logs.

> ⚠️ As mentioned in the documentation, this setup is ideal for all production environments, especially at scale. This is the recommended approach for securely syncing data to S3. It uses short-lived, automatically rotated credentials via an IAM role that Twingate assumes through OpenID Connect (OIDC). This setup reduces risk, simplifies credential management, and aligns with AWS security best practices.

## 📁 Directory Structure

```
aws-s3-sync-oidc-role/
├── main.tf                  # Main Terraform configuration
├── outputs.tf               # Output values shown after apply (e.g., OIDC Role Arn)
├── providers.tf             # AWS provider and version constraints
├── variables.tf             # Input variable definitions
├── terraform.tfvars.example # Sample variable values (copy and edit this)
└── README.md                # You're reading it!
```

## 🚀 What This Deploys

* An S3 bucket for storing Twingate logs.
* An OIDC role with `s3:PutObject` permission to that bucket.
* An OIDC Role Arn for use in the Twingate Admin Console.
* (Optional) A bucket policy to limit `PutObject` access to just this OIDC role.

## 🛠️ Setup Instructions

### 1. Configure your environment

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

* `aws_region` – AWS region to deploy in (e.g. `us-west-2`)
* `aws_bucket_name` – The S3 bucket name for logs (must be globally unique)
* `twingate_tenant_slug` – Your Twingate network slug (e.g. `acme` from `https://acme.twingate.com`)

Export your AWS credentials into the terminal session (skip if already configured):

```bash
export AWS_ACCESS_KEY_ID="ABCDEFG"
export AWS_SECRET_ACCESS_KEY="HIJKLMNOP"
export AWS_SESSION_TOKEN="XYZ123"
```

### 2. Deploy

Initialize, review, and apply the Terraform plan:

```bash
terraform init
terraform plan
terraform apply
```

## 🔐 Outputs

After a successful deploy, you'll get the following values:

* `twingate_s3_sync_role_name` – The name of the IAM role (helpful for debugging)
* `twingate_s3_sync_role_arn` – The OIDC role arn to configure in Twingate
* `twingate_s3_sync_bucket_name` – The S3 bucket name to configure in Twingate

## ✅ Cleanup

To delete everything:

```bash
terraform destroy
```

If you receive a `BucketNotEmpty` error, you may need to empty the S3 bucket first:

1. via the AWS CLI 
    ```bash
    aws s3 rm s3://your-bucket-name --recursive
    ```
2. or set `force_destroy = true` on the `aws_s3_bucket` resource.

Then run `terraform destroy` again.

## 🧠 Notes

* The IAM user and S3 bucket are created from scratch. This example assumes you're setting things up in a fresh AWS environment.

## 📚 Learn More

* [Twingate AWS S3 Sync docs](https://www.twingate.com/docs/syncing-data-to-s3)
* [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)