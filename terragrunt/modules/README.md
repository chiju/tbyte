# Terragrunt Modules

This directory contains reusable Terraform modules for the TByte infrastructure.

## Module Overview

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| [bootstrap](./bootstrap/) | S3 backend and cross-account roles | None |
| [vpc](./vpc/) | VPC with public/private subnets | None |
| [iam](./iam/) | GitHub Actions OIDC roles | None |
| [eks](./eks/) | EKS cluster with managed nodes | VPC |
| [rds](./rds/) | PostgreSQL database | VPC, EKS |
| [argocd](./argocd/) | GitOps deployment tool | EKS, IAM |

## Deployment Order

1. **Bootstrap** - Creates S3 backend and IAM roles
2. **VPC** - Creates network infrastructure
3. **IAM** - Creates GitHub Actions roles
4. **EKS** - Creates Kubernetes cluster
5. **RDS** - Creates database
6. **ArgoCD** - Deploys GitOps tooling

## Usage Pattern

Each environment (dev/staging/production) uses these modules:

```
environments/
├── dev/
│   ├── vpc/terragrunt.hcl
│   ├── iam/terragrunt.hcl
│   ├── eks/terragrunt.hcl
│   ├── rds/terragrunt.hcl
│   └── argocd/terragrunt.hcl
├── staging/
└── production/
```

## Common Inputs

All modules support these common inputs:

- `environment` - Environment name (dev/staging/production)
- `aws_region` - AWS region (default: eu-central-1)
- `assume_role_arn` - Cross-account role ARN (optional)

## Mock Outputs

All modules include mock outputs for planning:

```hcl
dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id = "vpc-mock"
    # ... other outputs
  }
}
```

This allows `terragrunt plan` to work without deploying dependencies first.
