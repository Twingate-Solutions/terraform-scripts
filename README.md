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
infraops/
├── modules/          # Reusable Terraform modules
│   ├── networking/   # Example: VPC, subnets, routing
│   └── twingate/     # Example: Twingate connector module
│
├── examples/         # Complete examples using modules
│   └── aws/
│       └── quickstart/
│           ├── main.tf
│           ├── variables.tf
│           └── README.md
│
├── sandboxes/        # Isolated, self-contained playgrounds for testing
│   └── aws-sandbox/
│       ├── main.tf
│       ├── providers.tf
│       ├── backend.tf
│       └── variables.tf
│
├── global/           # Shared provider & backend configuration
│   ├── providers.tf
│   ├── versions.tf
│   └── backend.tf
│
├── scripts/          # Optional automation (bootstrap, cleanup, etc.)
└── docs/             # Diagrams, usage guides, and documentation
````

### 🚀 Getting Started

1. Clone the repo:

   ```bash
   git clone https://github.com/your-org/infraops.git
   cd infraops
   ```

2. Navigate to a sandbox or example:

   ```bash
   cd sandboxes/aws-sandbox
   ```

3. Run Terraform:

   ```bash
   terraform init
   terraform apply
   ```

4. Tear down:

   ```bash
   terraform destroy
   ```

> ⚠️ Sandboxes are isolated and intended for testing and POCs. Avoid using them for persistent infrastructure.

### 🔧 Provider Versioning Strategy

To ensure consistency across clouds and environments, provider versions are pinned centrally in `global/`:

```hcl
terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    google  = { source = "hashicorp/google", version = "~> 5.0" }
  }

  required_version = ">= 1.6.0"
}
```

Each sandbox or example can override or extend these defaults.

### 🤝 Contributing

Pull requests are welcome! Please include a short description and ensure code is formatted (`terraform fmt`) and validated (`terraform validate`).
