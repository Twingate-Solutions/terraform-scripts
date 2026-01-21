# Twingate Connector Terraform Modules

This repository contains Terraform modules for deploying Twingate connectors on AWS using three different compute platforms: EC2, ECS, and EKS.

## Overview

The modules provide a flexible way to deploy Twingate connectors with configurable options for networking, scaling, security, and monitoring. Each module is designed to handle different use cases and deployment preferences.

## Modules

### 1. EC2 Module (`modules/twingate-ec2`)

Deploys Twingate connectors on EC2 instances using Auto Scaling Groups.

**Features:**
- Auto Scaling Group with configurable capacity
- Security Groups with customizable rules
- IAM roles and instance profiles
- Optional Elastic IP for static public addressing
- SSM support for secure management
- CloudWatch monitoring integration
- User data script for automated connector installation

**Use Cases:**
- Traditional VM-based deployments
- When you need direct control over the underlying infrastructure
- Hybrid environments requiring specific instance configurations

### 2. ECS Module (`modules/twingate-ecs`)

Deploys Twingate connectors on Amazon ECS using Fargate or EC2 launch types.

**Features:**
- Support for both Fargate and EC2 launch types
- Fargate Spot capacity provider support
- Application Auto Scaling with CPU and memory metrics
- CloudWatch Logs integration
- Optional Network Load Balancer for public IP requirements
- Service discovery integration
- AWS Secrets Manager integration for secure credential management

**Use Cases:**
- Containerized deployments without Kubernetes overhead
- Cost-optimized deployments using Fargate Spot
- Serverless container deployments
- Integration with existing ECS infrastructure

### 3. EKS Module (`modules/twingate-eks`)

Deploys Twingate connectors on Amazon EKS as Kubernetes Deployments.

**Features:**
- Kubernetes-native deployment with ConfigMaps and Secrets
- Horizontal Pod Autoscaler (HPA) support
- Pod Disruption Budget (PDB) for high availability
- Network Policies for security
- Flexible scheduling with node selectors, tolerations, and affinity
- Service creation for internal communication
- Support for OpenShift Security Context Constraints

**Use Cases:**
- Kubernetes-native environments
- Complex scheduling requirements
- Integration with existing Kubernetes tooling and workflows
- Multi-tenant environments with namespace isolation

## Quick Start

### Prerequisites

1. **Terraform** >= 1.0
2. **AWS CLI** configured with appropriate permissions
3. **kubectl** configured for EKS deployments
4. **Twingate Account** with connector tokens

### Basic Usage

1. **Clone the repository:**
```bash
git clone <repository-url>
cd twingate-terraform-modules
```

2. **Copy the example configuration:**
```bash
cp examples/terraform.tfvars.example examples/terraform.tfvars
```

3. **Update the variables:**
Edit `examples/terraform.tfvars` with your specific values.

4. **Initialize and apply:**
```bash
cd examples
terraform init
terraform plan
terraform apply
```

## Configuration Options

### Network Configuration

All modules support flexible network configuration:

- **VPC and Subnets**: Specify existing VPC and subnet IDs
- **Public/Private IP**: Configure whether connectors get public IPs
- **NAT Gateway**: Use NAT Gateway for outbound internet access from private subnets
- **Security Groups**: Customizable security group rules for internal network access

### Twingate Configuration

Configure your Twingate connector settings:

```hcl
twingate_url           = "https://mycompany.twingate.com"
twingate_access_token  = "your-access-token"
twingate_refresh_token = "your-refresh-token"
log_level             = 4
log_analytics         = true
status_reports_v1     = true
```

### Scaling Configuration

Each module provides different scaling options:

**EC2 Module:**
```hcl
min_size         = 1
max_size         = 3
desired_capacity = 2
```

**ECS Module:**
```hcl
desired_count = 2
enable_autoscaling = true
autoscaling_min_capacity = 1
autoscaling_max_capacity = 5
```

**EKS Module:**
```hcl
replicas = 2
enable_hpa = true
hpa_min_replicas = 1
hpa_max_replicas = 5
```

## Security Best Practices

### 1. Credential Management

**For ECS deployments**, use AWS Secrets Manager:
```hcl
# Create secrets
resource "aws_secretsmanager_secret" "twingate_access_token" {
  name = "twingate-access-token"
}

# Reference in module
twingate_access_token_secret_arn = aws_secretsmanager_secret.twingate_access_token.arn
```

**For EC2 and EKS deployments**, consider using:
- Environment variables
- AWS Parameter Store
- External secret management solutions like HashiCorp Vault

### 2. Network Security

- Deploy in private subnets when possible
- Use NAT Gateway or NAT Instance for outbound internet access
- Implement least-privilege security group rules
- Enable VPC Flow Logs for network monitoring

### 3. IAM Security

- Use IAM roles instead of access keys
- Follow principle of least privilege
- Enable CloudTrail for API logging
- Regular security audits

## Advanced Configuration Examples

### High Availability EC2 Deployment

```hcl
module "twingate_ec2_ha" {
  source = "./modules/twingate-ec2"
  
  name_prefix = "twingate-ha"
  subnet_id   = var.subnet_id
  
  # Multi-AZ deployment
  min_size         = 2
  max_size         = 6
  desired_capacity = 3
  
  # Enhanced monitoring
  enable_detailed_monitoring = true
  enable_ssm = true
  
  # Security
  assign_public_ip = false
  internal_cidr_blocks = [
    "10.0.0.0/8",
    "172.16.0.0/12"
  ]
}
```

### Cost-Optimized ECS with Spot Instances

```hcl
module "twingate_ecs_spot" {
  source = "./modules/twingate-ecs"
  
  name_prefix = "twingate-spot"
  subnet_ids  = var.private_subnet_ids
  
  # Use Fargate Spot
  capacity_provider_strategies = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight           = 100
      base             = 1
    }
  ]
  
  # Smaller resources for cost savings
  cpu    = 256
  memory = 512
}
```

### Production EKS with Full Observability

```hcl
module "twingate_eks_production" {
  source = "./modules/twingate-eks"
  
  name_prefix = "twingate-prod"
  subnet_ids  = var.private_subnet_ids
  
  # High availability
  replicas = 3
  enable_pdb = true
  pdb_max_unavailable = "1"
  
  # Auto scaling
  enable_hpa = true
  hpa_min_replicas = 2
  hpa_max_replicas = 10
  
  # Observability
  pod_annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = "8080"
    "prometheus.io/path"   = "/metrics"
  }
  
  # Health checks
  liveness_probe = {
    path = "/health"
    port = 8080
    initial_delay_seconds = 60
  }
  
  readiness_probe = {
    path = "/ready"
    port = 8080
    initial_delay_seconds = 10
  }
}
```

## Troubleshooting

### Common Issues

1. **Connector not connecting to Twingate:**
   - Verify access and refresh tokens are correct
   - Check security group allows outbound HTTPS (443) and Twingate relay ports (30000-31000)
   - Ensure DNS resolution is working

2. **Auto Scaling not working:**
   - Check CloudWatch metrics are being published
   - Verify IAM permissions for auto scaling
   - Review scaling policies and thresholds

3. **EKS deployment fails:**
   - Ensure kubectl is configured correctly
   - Check RBAC permissions
   - Verify node groups have capacity

### Logging and Monitoring

**CloudWatch Logs:**
- EC2: Check `/var/log/twingate/` on instances
- ECS: Logs automatically sent to CloudWatch Logs
- EKS: Use `kubectl logs` or configure log forwarding

**Metrics:**
- Enable detailed monitoring in modules
- Use CloudWatch dashboards for visualization
- Set up CloudWatch alarms for critical metrics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## Support

For issues with the Terraform modules:
- Check the troubleshooting guide above
- Review module documentation
- Open an issue in this repository

For Twingate-specific issues:
- Consult Twingate documentation
- Contact Twingate support

## License

This project is licensed under the MIT License - see the LICENSE file for details.