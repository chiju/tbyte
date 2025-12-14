# TByte Infrastructure - Terragrunt

> **Production-Ready Multi-Account AWS Infrastructure**

This repository contains Terragrunt configurations for deploying TByte infrastructure across multiple AWS accounts using Infrastructure as Code best practices.

## 🏗️ Architecture Overview

```
AWS Organizations (Root: 432801802107)
├── Dev Account (045129524082)     - Development environment
├── Staging Account (860655786215) - Pre-production testing  
└── Production Account (136673894425) - Production workloads
```

## 📁 Repository Structure

```
terragrunt/
├── README.md                    # This file
├── root.hcl                    # Common Terragrunt configuration
├── backend.tf                  # Remote state configuration template
├── provider.tf                 # AWS provider configuration template
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC with public/private subnets
│   ├── eks/                   # EKS cluster with managed nodes
│   ├── rds/                   # PostgreSQL database
│   ├── iam/                   # GitHub Actions OIDC roles
│   ├── ecr/                   # Container registry
│   ├── argocd/                # GitOps deployment
│   └── bootstrap/             # S3 backend setup
├── environments/              # Environment-specific configurations
│   ├── dev/                  # Development (045129524082)
│   ├── staging/              # Staging (860655786215)
│   └── production/           # Production (136673894425)
└── shared-services/          # Cross-account shared resources
```

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
aws --version        # AWS CLI v2
terragrunt --version # Terragrunt v0.67.16+
terraform --version  # Terraform v1.13.5+
```

### 1. Configure AWS Credentials

```bash
# Configure AWS profiles for each account
aws configure --profile dev_4082
aws configure --profile staging_8607
aws configure --profile prod_1366

# Or use environment variables
export AWS_PROFILE=dev_4082
export AWS_REGION=eu-central-1
```

### 2. Deploy Development Environment

```bash
# Clone repository
git clone https://github.com/chiju/tbyte.git
cd tbyte/terragrunt/environments/dev

# Deploy all modules in dependency order
terragrunt run-all plan    # Review changes
terragrunt run-all apply   # Deploy infrastructure

# Or deploy modules individually
cd vpc && terragrunt apply
cd ../eks && terragrunt apply
cd ../rds && terragrunt apply
```

### 3. Verify Deployment

```bash
# Check EKS cluster
aws eks describe-cluster --name tbyte-dev --region eu-central-1

# Configure kubectl
aws eks update-kubeconfig --name tbyte-dev --region eu-central-1

# Verify nodes
kubectl get nodes
```

## 🏢 Environment Configurations

### Development Environment
```bash
cd environments/dev
terragrunt run-all apply --terragrunt-non-interactive
```

**Resources Created:**
- VPC: `vpc-0f0359687a44abb93` (10.0.0.0/16)
- EKS: `tbyte-dev` (Kubernetes 1.34)
- RDS: `tbyte-dev-postgres` (PostgreSQL 15.15)
- ECR: `tbyte-dev-frontend`, `tbyte-dev-backend`

### Staging Environment
```bash
# Switch to staging account
export AWS_PROFILE=staging_8607

cd environments/staging
terragrunt run-all apply --terragrunt-non-interactive
```

### Production Environment
```bash
# Switch to production account  
export AWS_PROFILE=prod_1366

cd environments/production
terragrunt run-all apply --terragrunt-non-interactive
```

## 📋 Module Usage Examples

### VPC Module
```hcl
# environments/dev/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  cluster_name       = "tbyte-dev"
  environment        = "dev"
  cidr              = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
}
```

### EKS Module with Dependencies
```hcl
# environments/dev/eks/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id             = "vpc-mock"
    public_subnet_ids  = ["subnet-mock-1", "subnet-mock-2"]
    private_subnet_ids = ["subnet-mock-3", "subnet-mock-4"]
  }
}

inputs = {
  cluster_name       = "tbyte-dev"
  environment        = "dev"
  kubernetes_version = "1.34"
  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Node configuration
  node_instance_type = "t3.medium"
  desired_nodes     = 2
  min_nodes         = 1
  max_nodes         = 3
}
```

### RDS Module
```hcl
# environments/dev/rds/terragrunt.hcl
inputs = {
  cluster_name            = "tbyte-dev"
  environment            = "dev"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  backup_retention_period = 1
  multi_az              = false  # Cost optimization for dev
}
```

## 🔧 Common Operations

### Planning Changes
```bash
# Plan all modules
terragrunt run-all plan

# Plan specific module
cd vpc && terragrunt plan

# Plan with variable override
terragrunt plan -var="node_instance_type=t3.large"
```

### Applying Changes
```bash
# Apply all modules
terragrunt run-all apply --terragrunt-non-interactive

# Apply specific module
cd eks && terragrunt apply

# Apply with auto-approve
terragrunt apply --auto-approve
```

### State Management
```bash
# List resources in state
terragrunt state list

# Show specific resource
terragrunt state show aws_eks_cluster.main

# Import existing resource
terragrunt import aws_vpc.main vpc-0f0359687a44abb93
```

### Destroying Resources
```bash
# Destroy all modules (reverse dependency order)
terragrunt run-all destroy

# Destroy specific module
cd rds && terragrunt destroy

# Force destroy (skip confirmations)
terragrunt destroy --terragrunt-non-interactive
```

## 🔐 Security & Best Practices

### IAM Roles and Permissions
```bash
# GitHub Actions OIDC roles per environment
arn:aws:iam::045129524082:role/github-actions-role     # Dev
arn:aws:iam::860655786215:role/github-actions-role     # Staging  
arn:aws:iam::136673894425:role/github-actions-role     # Production
```

### State File Security
- **Encryption**: All state files encrypted with S3 server-side encryption
- **Versioning**: S3 versioning enabled for state file recovery
- **Locking**: DynamoDB table prevents concurrent modifications
- **Access Control**: IAM policies restrict state file access

### Network Security
- **Private Subnets**: EKS nodes and RDS in private subnets only
- **Security Groups**: Least-privilege network access rules
- **VPC Isolation**: Separate VPCs per environment
- **NAT Gateways**: Controlled internet access for private resources

## 🚨 Troubleshooting

### Common Issues

**Issue**: `Error: NoCredentialsError`
```bash
# Fix: Configure AWS credentials
aws configure --profile dev_4082
export AWS_PROFILE=dev_4082
```

**Issue**: `Error: state lock`
```bash
# Fix: Force unlock (use carefully)
terragrunt force-unlock <lock-id>
```

**Issue**: `Error: cycle detected`
```bash
# Fix: Check dependency graph
terragrunt graph-dependencies
# Remove circular dependencies in configuration
```

**Issue**: `Error: resource not found`
```bash
# Fix: Import existing resource
terragrunt import aws_vpc.main vpc-0f0359687a44abb93
```

### State Recovery
```bash
# List S3 state versions
aws s3api list-object-versions \
  --bucket tbyte-terragrunt-state-045129524082 \
  --prefix environments/dev/vpc/terraform.tfstate

# Restore from backup
aws s3api get-object \
  --bucket tbyte-terragrunt-state-045129524082 \
  --key environments/dev/vpc/terraform.tfstate \
  --version-id <version-id> \
  backup_state.json

terragrunt state push backup_state.json
```

## 📊 Cost Optimization

### Environment Costs (Estimated)
- **Development**: ~$150-200/month
  - EKS: $73/month (control plane)
  - RDS: $13/month (db.t3.micro, single-AZ)
  - NAT Gateway: $45/month
  - Other: $20-65/month

- **Staging**: ~$300-400/month
  - Similar to dev with larger instances

- **Production**: ~$800-1200/month
  - Multi-AZ RDS: $200+/month
  - Larger instance types
  - Reserved instances (40% savings)

### Cost Optimization Tips
```hcl
# Use smaller instances for dev
node_instance_type = "t3.small"    # Dev
node_instance_type = "t3.medium"   # Staging
node_instance_type = "m5.large"    # Production

# Single-AZ for dev, Multi-AZ for production
multi_az = false  # Dev/Staging
multi_az = true   # Production

# Shorter backup retention for dev
backup_retention_period = 1   # Dev
backup_retention_period = 30  # Production
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow
The infrastructure is deployed via GitHub Actions pipeline:

```yaml
# .github/workflows/terragrunt.yml
- name: Deploy Dev Environment
  working-directory: terragrunt/environments/dev
  run: |
    cd vpc && terragrunt apply --auto-approve
    cd ../eks && terragrunt apply --auto-approve
    cd ../rds && terragrunt apply --auto-approve
```

### Manual Deployment
```bash
# Trigger manual deployment
gh workflow run terragrunt.yml

# Check deployment status
gh run list --workflow=terragrunt.yml
```

## 📚 Additional Resources

### Documentation
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

### Module Documentation
- [VPC Module](./modules/vpc/README.md)
- [EKS Module](./modules/eks/README.md)
- [RDS Module](./modules/rds/README.md)
- [IAM Module](./modules/iam/README.md)

### Support
- **Issues**: [GitHub Issues](https://github.com/chiju/tbyte/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chiju/tbyte/discussions)
- **Documentation**: [Technical Documentation](../docs/technical-documentation.md)

## 🧹 Cleanup

### Destroy All Resources
```bash
# Destroy development environment
cd environments/dev
terragrunt run-all destroy --terragrunt-non-interactive

# Destroy staging environment
export AWS_PROFILE=staging_8607
cd ../staging
terragrunt run-all destroy --terragrunt-non-interactive

# Destroy production environment
export AWS_PROFILE=prod_1366
cd ../production
terragrunt run-all destroy --terragrunt-non-interactive
```

**⚠️ Warning**: This will destroy all infrastructure and cannot be undone. Ensure you have backups of any important data.

---

**Note**: This infrastructure demonstrates production-ready DevOps practices including Infrastructure as Code, multi-account deployment, security best practices, and automated CI/CD pipelines.
