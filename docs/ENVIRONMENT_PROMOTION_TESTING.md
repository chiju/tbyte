# Environment Promotion Testing Guide

## Overview

This guide explains how to test the environment promotion pipeline that implements the **single build, multi-env deploy** pattern required by the assessment.

## Pipeline Design

```
Build Once → DEV (auto) → STAGING (approval) → PRODUCTION (strict approval)
```

### Key Features
- ✅ **Single Build**: One Docker image built and promoted through environments
- ✅ **Environment-Specific Config**: Different resources/replicas per environment
- ✅ **Protected Environments**: Manual approvals for staging/production
- ✅ **Traceability**: Same image tag tracked across all environments

## How to Test

### 1. Setup GitHub Environments

First, create protected environments in your GitHub repo:

```bash
# Go to: Settings → Environments → New environment
# Create: dev, staging, production
# For staging/production: Add required reviewers
```

### 2. Test DEV Auto-Deployment

```bash
# Push to main branch triggers auto-deploy to DEV
git add .
git commit -m "test: trigger dev deployment"
git push origin main

# Verify DEV deployment
kubectl get pods -n dev
./scripts/test-environment-promotion.sh --dev
```

### 3. Test STAGING Promotion

```bash
# Manually trigger staging deployment (requires approval)
gh workflow run environment-promotion.yml -f promote_to=staging

# After approval, verify staging
kubectl get pods -n staging
./scripts/test-environment-promotion.sh --staging
```

### 4. Test PRODUCTION Promotion

```bash
# Manually trigger production deployment (strict approval)
gh workflow run environment-promotion.yml -f promote_to=production

# After approval, verify production
kubectl get pods -n default
./scripts/test-environment-promotion.sh --prod
```

### 5. Run Complete Test Suite

```bash
# Test all environments at once
./scripts/test-environment-promotion.sh

# Expected output:
# ✅ DEV namespace exists
# ✅ Frontend running in DEV
# ✅ Backend running in DEV
# ✅ STAGING namespace exists
# ✅ Frontend has correct replica count in STAGING (2)
# ✅ Frontend running in PRODUCTION
# ✅ Same image tag across all environments
# 🎉 All environment promotion tests passed!
```

## Environment Differences

| Environment | Replicas | Resources | Persistence | Auto-scaling | Approval |
|-------------|----------|-----------|-------------|--------------|----------|
| **DEV**     | 1        | Low       | No          | Disabled     | None     |
| **STAGING** | 2        | Medium    | Yes         | Enabled      | Manual   |
| **PRODUCTION** | 2+    | High      | Yes         | Enabled      | Strict   |

## Validation Checklist

### ✅ Single Build Pattern
- [ ] Same Docker image tag used across all environments
- [ ] No rebuilding during promotion
- [ ] Image stored in ECR with git SHA tag

### ✅ Environment-Specific Configuration
- [ ] Different resource limits per environment
- [ ] Different replica counts per environment
- [ ] Environment-specific domains/ingress

### ✅ Protected Environments
- [ ] DEV deploys automatically on main push
- [ ] STAGING requires manual approval
- [ ] PRODUCTION requires strict approval + staging success

### ✅ Traceability
- [ ] Git SHA visible in image tags
- [ ] Deployment history in GitHub Actions
- [ ] Kubernetes deployment annotations

## Troubleshooting

### Pipeline Fails at Build Stage
```bash
# Check build logs
gh run list --workflow=environment-promotion.yml
gh run view <run-id>

# Common issues:
# - ECR permissions
# - Docker build failures
# - Test failures
```

### Environment Deployment Fails
```bash
# Check Kubernetes resources
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Check Helm deployment
helm list -n <namespace>
helm status <release-name> -n <namespace>
```

### Approval Not Working
```bash
# Check environment protection rules
# Go to: Settings → Environments → <env-name>
# Verify: Required reviewers are set
# Verify: Branch restrictions if needed
```

## Demo Script

For assessment demonstration:

```bash
# 1. Show current state
kubectl get pods --all-namespaces | grep tbyte

# 2. Trigger promotion
echo "Promoting build $(git rev-parse --short HEAD) to staging..."
gh workflow run environment-promotion.yml -f promote_to=staging

# 3. Show approval required
echo "Approval required - check GitHub Actions"

# 4. After approval, verify
./scripts/test-environment-promotion.sh

# 5. Show image consistency
echo "Same image across environments:"
kubectl get deployments -o wide --all-namespaces | grep tbyte
```

## Assessment Compliance

This implementation satisfies:

- **Task B3**: ✅ CI/CD pipeline with environment promotion
- **Protected Environments**: ✅ Manual approvals for stage/prod
- **Single Artifact**: ✅ Same Docker image promoted through environments
- **IaC Integration**: ✅ Helm charts with environment-specific values
- **Traceability**: ✅ Git SHA tracking and deployment history

## Next Steps

1. **Run the test script** to validate current setup
2. **Create GitHub environments** with protection rules
3. **Test the promotion flow** end-to-end
4. **Document any issues** and fixes in your technical document
