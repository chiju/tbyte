# Single-Account Environment Promotion

## Overview

This implements environment promotion using **namespaces** in a single AWS account/EKS cluster, which is perfect for the assessment requirements.

## Design

```
Single EKS Cluster
├── dev namespace (1 replica, auto-deploy)
├── staging namespace (2 replicas, manual)
└── prod namespace (3 replicas, manual)
```

## How It Works

### 1. Single Build Pattern ✅
- One Docker image built with git SHA tag
- Same image promoted through all environments
- No rebuilding during promotion

### 2. Environment Separation ✅
- **DEV**: `dev` namespace, 1 replica, auto-deploy on PR/main
- **STAGING**: `staging` namespace, 2 replicas, manual trigger
- **PRODUCTION**: `prod` namespace, 3 replicas, manual trigger

### 3. Configuration Differences ✅
- Same image, different Helm parameters per environment
- Different resource limits and replica counts
- Environment-specific labels and annotations

## Quick Test

```bash
# Test current setup
./scripts/test-single-account-promotion.sh

# Test specific environment
./scripts/test-single-account-promotion.sh --dev
./scripts/test-single-account-promotion.sh --staging
./scripts/test-single-account-promotion.sh --production

# Check image consistency
./scripts/test-single-account-promotion.sh --images
```

## Manual Promotion Flow

```bash
# 1. Build and deploy to DEV (automatic on main push)
git push origin main

# 2. Promote to STAGING (manual)
gh workflow run environment-promotion-simple.yml -f promote_to=staging

# 3. Promote to PRODUCTION (manual)
gh workflow run environment-promotion-simple.yml -f promote_to=production
```

## Verification

```bash
# Check all environments
kubectl get pods --all-namespaces | grep tbyte

# Check ArgoCD apps
kubectl get applications -n argocd

# Check image tags are consistent
kubectl get applications -n argocd -o yaml | grep "image.tag"
```

## Assessment Compliance

This satisfies all requirements:

- ✅ **Single Build**: One Docker image with git SHA
- ✅ **Environment Promotion**: dev → staging → production
- ✅ **Protected Environments**: Manual triggers for staging/prod
- ✅ **Configuration Management**: Helm parameters per environment
- ✅ **Traceability**: Git SHA tracking across environments
- ✅ **Single Account**: No need for multiple AWS accounts

## Benefits

- **Simple**: Uses existing EKS cluster
- **Cost-effective**: No additional infrastructure
- **Realistic**: Matches real-world single-account setups
- **Testable**: Easy to validate and demonstrate
