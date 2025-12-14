# Terragrunt Quick Start Guide

## 🚀 Deploy Everything
```bash
# Deploy all components sequentially
cd terragrunt
export AWS_PROFILE=oth_infra

# Option 1: Pipeline (Recommended)
git push origin main

# Option 2: Manual
terragrunt apply --terragrunt-working-dir bootstrap
terragrunt apply --terragrunt-working-dir shared-services
terragrunt apply --terragrunt-working-dir environments/dev/vpc
terragrunt apply --terragrunt-working-dir environments/dev/eks
terragrunt apply --terragrunt-working-dir environments/dev/rds
```

## 🧹 Cleanup Everything
```bash
# Via pipeline (safe)
gh workflow run cleanup.yml -f confirm=destroy

# Manual (careful!)
cd terragrunt
terragrunt run-all destroy
```

## 📁 Structure
```
terragrunt/
├── bootstrap/           # Creates accounts, OIDC, roles
├── shared-services/     # ECR repositories
└── environments/
    ├── dev/            # Development environment
    ├── staging/        # Staging environment
    └── production/     # Production environment
```

## 🔍 Troubleshooting
```bash
# Check specific component
terragrunt plan --terragrunt-working-dir environments/dev/vpc

# View dependencies
terragrunt graph-dependencies

# Debug issues
terragrunt apply --terragrunt-working-dir bootstrap --terragrunt-log-level debug
```

## 📊 Deployment Order
1. **Bootstrap** (5 min) → Creates accounts, OIDC, roles
2. **Shared Services** (2 min) → ECR repositories
3. **VPC** (3 min) → Network infrastructure
4. **EKS** (10 min) → Kubernetes cluster
5. **RDS** (5 min) → Database

**Total**: ~25 minutes for complete dev environment
