# AWS S3 Sync for Twingate (IAM User Example)

This is a standalone example using Terraform to provision an **S3 bucket and IAM user** that can be used with [Twingate’s AWS S3 Sync](https://www.twingate.com/docs/syncing-data-to-s3) to ingest logs.

> ⚠️ As mentioned in the documentation, this setup is ideal for smaller teams or simpler environments without an identity provider as it configures the S3 sync using static IAM user credentials. While still supported, this method requires careful handling due to its reliance on long-lived access keys and manual rotation.

## 📁 Directory Structure

```
aws-s3-sync-iam-user/
├── main.tf                  # Main Terraform configuration
├── outputs.tf               # Output values shown after apply (e.g., IAM access keys)
├── providers.tf             # AWS provider and version constraints
├── variables.tf             # Input variable definitions
├── terraform.tfvars.example # Sample variable values (copy and edit this)
└── README.md                # You're reading it!
```

## 🚀 What This Deploys

* An S3 bucket for storing Twingate logs.
* An IAM user with `s3:PutObject` permission to that bucket.
* An access key and secret for use in the Twingate Admin Console.
* (Optional) A bucket policy to limit `PutObject` access to just this user.

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

* `twingate_s3_sync_access_key_id` – The IAM Access Key ID (used in Twingate Admin Console)
* `twingate_s3_sync_secret_access_key` – The IAM Secret Access Key (also needed in Twingate)
* `twingate_s3_sync_bucket_name` – The S3 bucket name to configure in Twingate

> ⚠️ Be sure to store the `twingate_s3_sync_secret_access_key` securely. It will not be shown again after `terraform apply` but can be retrieved in the terminal with `terraform output -raw twingate_s3_sync_secret_access_key` for use in the Twingate Admin Console.

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