# Industry Best Practices: Infrastructure vs Application Deployment

## How It Really Works in Industry

### Infrastructure (Terraform) - RARELY CHANGES
- **When:** Only when infrastructure needs change (new services, scaling, security updates)
- **Frequency:** Weekly/Monthly or less
- **Who:** DevOps/Platform teams
- **Examples:** Adding new EKS cluster, changing instance types, new RDS database

### Application Code (Docker + ArgoCD) - CHANGES FREQUENTLY  
- **When:** Every code change, bug fix, new feature
- **Frequency:** Multiple times per day
- **Who:** Developers
- **Examples:** API changes, UI updates, bug fixes

## Real Industry Workflow

### 1. Developer Makes Code Change
```bash
# Developer commits code
git commit -m "fix: user login bug"
git push origin feature/login-fix
```

### 2. CI/CD Pipeline (GitHub Actions)
```bash
# Automatically triggered on push
- Build Docker image
- Run tests
- Push to ECR with new tag (git SHA)
- NO TERRAFORM RUNS
```

### 3. ArgoCD Handles Deployment
```bash
# ArgoCD detects new image tag
- Pulls new image from ECR
- Updates Kubernetes deployments
- Rolls out new version
- NO TERRAFORM INVOLVED
```

## What Runs When

| Change Type | Terraform | Docker Build | ArgoCD | Example |
|-------------|-----------|--------------|--------|---------|
| **Code Change** | ❌ No | ✅ Yes | ✅ Yes | Bug fix, new feature |
| **Config Change** | ❌ No | ❌ No | ✅ Yes | Environment variables |
| **Infrastructure Change** | ✅ Yes | ❌ No | ❌ No | New database, scaling |

## Industry Pattern: GitOps

### Infrastructure Repository (Terraform)
- Changes rarely (weeks/months)
- Managed by DevOps team
- Creates: EKS, RDS, VPC, etc.

### Application Repository (Code)
- Changes frequently (daily)
- Managed by developers  
- Creates: Docker images

### Config Repository (Kubernetes YAML)
- Changes occasionally
- Managed by both teams
- ArgoCD watches this repo

## Your TByte Setup (Industry Standard)

### Phase 1: Infrastructure Setup (One-time)
```bash
# DevOps team runs this once
terraform apply  # Creates EKS cluster
```

### Phase 2: Application Deployment (Ongoing)
```bash
# Developers push code daily
git push → GitHub Actions → Docker build → ECR → ArgoCD → Kubernetes
```

## Best Practices

### ✅ DO
- Separate infrastructure and application pipelines
- Use ArgoCD for application deployments
- Only run Terraform when infrastructure changes
- Use image tags (git SHA) for traceability

### ❌ DON'T  
- Run Terraform on every code change
- Mix infrastructure and application deployments
- Use "latest" image tags
- Deploy directly to Kubernetes (bypass ArgoCD)

## Real Example Timeline

### Week 1: Setup Infrastructure
```bash
Day 1: DevOps runs terraform apply (creates EKS)
Day 2-7: No Terraform runs
```

### Week 2-4: Daily Development
```bash
Daily: Developers push code
Daily: GitHub Actions builds images  
Daily: ArgoCD deploys new versions
Terraform: Not touched for weeks
```

### Month 2: Infrastructure Change
```bash
Need: Add new database
Action: DevOps runs terraform apply
Result: New RDS created, apps keep running
```

## Your Assessment Advantage

This setup shows you understand:
- ✅ **Separation of Concerns**: Infrastructure vs Application
- ✅ **GitOps Principles**: Declarative deployments
- ✅ **Industry Standards**: How real companies work
- ✅ **Operational Efficiency**: Right tool for right job

**Bottom Line:** Terraform runs rarely, Docker/ArgoCD runs frequently. This is exactly how Netflix, Spotify, and other tech companies do it.
