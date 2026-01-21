# Terraform Scripts

🙋‍♂️ **Welcome to the Twingate Solutions Terraform Scripts Repository!**

This repository is maintained by the Twingate Solutions Engineering team to help customers deploy, test, and explore Twingate across cloud environments using Terraform.

### 🌐 Overview

This repo offers:

- **Reference Terraform** for deploying infrastructure on AWS (Azure & GCP coming soon)
- **Reusable Terraform modules** to streamline cloud infrastructure provisioning
- **Sandbox environments** for safe, isolated experimentation and proof-of-concept validation

### 📁 Directory Structure

```bash
terraform-scripts/
├── modules/          # Reusable Terraform modules for deploying Twingate in different environments
│   ├── aws/          # Amazon
│   │   ├── connectors/
│   │   │   ├── ec2/
│   │   │   ├── ecs/
│   │   │   └── eks/
│   │   └── s3-sync/
│   │   │   ├── iam/
│   │   │   └── oidc/
│   ├── azure/        # Azure
│   ├── do/           # DigitalOcean
│   ├── gcp/          # Google
│   ├── oci/          # Oracle
│   └── twingate/     # RemoteNetworks, Connectors, Resources, etc.
│
├── examples/         # Complete examples using modules or direct code
├── sandboxes/        # Isolated, self-contained playgrounds for testing/POCs
├── scripts/          # Optional automation (bootstrap, cleanup, etc.)
└── docs/             # Diagrams, usage guides, and documentation
````

### 🚀 Getting Started

1. Clone the repo:

   ```bash
   git clone https://github.com/Twingate-Solutions/terraform-scripts.git
   cd terraform-scripts
   ```

2. Navigate to a sandbox or example:

   ```bash
   cd sandboxes/aws-sandbox
   ```

3. Configure your environment

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`, example:

* `aws_region` – AWS region to deploy in (e.g. `us-west-2`)
* `aws_bucket_name` – The S3 bucket name for logs (must be globally unique)
* `twingate_tenant_slug` – Your Twingate network slug (e.g. `acme` from `https://acme.twingate.com`)

Export any other credentials into the terminal session (skip if already configured):

```bash
export ABC_ACCESS_KEY_ID="ABCDEFG"
export ABC_SECRET_ACCESS_KEY="HIJKLMNOP"
export ABC_SESSION_TOKEN="XYZ123"
```

3. Run Terraform:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Tear down:

   ```bash
   terraform destroy
   ```

> ⚠️ Sandboxes are isolated and intended for testing and POCs. Avoid using them for persistent infrastructure.

### 🤝 Contributing

Pull requests are welcome! Please include a short description and ensure code is formatted (`terraform fmt`) and validated (`terraform validate`).
