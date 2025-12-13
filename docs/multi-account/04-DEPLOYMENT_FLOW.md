# Deployment Flow: What Happens When We Push

## 🚀 **Trigger Event**
```bash
git push origin feature/environment-promotion
```

## 📋 **Step-by-Step Flow**

### 1. GitHub Detects Changes ⚡
- **Trigger**: Push to branch with `.github/workflows/terraform.yml` changes
- **Pipeline**: `terraform.yml` workflow starts
- **Environment**: Defaults to `dev` (TARGET_ENV = dev)

### 2. Validation Jobs Run (2-3 minutes) 🔍
```
validate job:
├── Checkout code
├── Setup Terraform v1.13.5
├── terraform fmt -check (code formatting)
├── terraform init -backend=false
└── terraform validate (syntax check)

security job:
├── Checkout code
├── Run Checkov security scan
└── Check for security issues
```

### 3. Plan Job Runs (3-5 minutes) 📋
```
plan job:
├── Checkout code
├── Setup Terraform
├── Configure AWS credentials (Root account: 432801802107)
├── terraform init (download providers, setup backend)
├── terraform plan with variables:
│   ├── target_environment = "dev"
│   ├── dev_account_id = "761380703881"
│   ├── staging_account_id = "342206309355"
│   ├── production_account_id = "155684258115"
│   ├── github_app_id = (from secrets)
│   ├── github_app_installation_id = (from secrets)
│   └── github_app_private_key = (from secrets)
└── Save plan artifact if changes detected
```

### 4. Apply Job Runs (10-15 minutes) 🏗️
**Only runs if plan shows changes**
```
apply job:
├── Checkout code
├── Setup Terraform
├── Configure AWS credentials (Root account)
├── terraform init
├── Download plan artifact
├── terraform apply -auto-approve tfplan
│   └── This creates in DEV account (761380703881):
│       ├── VPC with public/private subnets
│       ├── EKS cluster "tbyte-dev"
│       ├── EKS node group (1 t3.small node)
│       ├── RDS PostgreSQL database
│       ├── ECR repositories
│       ├── IAM roles and policies
│       └── ArgoCD installation
├── Switch to DEV account credentials
├── aws eks update-kubeconfig --name tbyte-dev
├── kubectl wait for nodes to be ready
├── kubectl wait for ArgoCD to be running
└── Success notification
```

## 🎯 **What Gets Created in DEV Account (761380703881)**

### Infrastructure Components:
```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── NAT Gateway
│   └── Internet Gateway
├── Private Subnets (2 AZs)
│   ├── EKS Nodes
│   └── RDS Database
└── Security Groups

EKS Cluster "tbyte-dev"
├── Control Plane (managed by AWS)
├── Node Group
│   ├── Instance Type: t3.small
│   ├── Desired: 1 node
│   ├── Min: 1, Max: 3
│   └── Auto Scaling Group
└── Add-ons (VPC CNI, CoreDNS, kube-proxy)

RDS PostgreSQL
├── Instance: db.t3.micro
├── Database: tbyte
├── Storage: 20GB
├── Multi-AZ: false (cost optimization)
└── Backup: 1 day retention

ECR Repositories
├── tbyte-frontend
└── tbyte-backend

IAM Roles
├── EKS Cluster Role
├── EKS Node Group Role
├── Backend Service Account Role (IRSA)
└── ArgoCD Service Account Role
```

### Kubernetes Components:
```
ArgoCD Namespace
├── argocd-server
├── argocd-repo-server
├── argocd-application-controller
├── argocd-dex-server
└── argocd-redis

ArgoCD Applications (GitOps)
├── Core Apps (app-of-apps pattern)
├── Monitoring Stack
├── Logging Stack
└── TByte Microservices (when ready)
```

## ⏱️ **Timeline**

| Phase | Duration | What Happens |
|-------|----------|--------------|
| **Validation** | 2-3 min | Code checks, security scan |
| **Planning** | 3-5 min | Terraform plan, artifact save |
| **Infrastructure** | 10-15 min | EKS cluster creation |
| **Post-Deploy** | 2-3 min | Verification, ArgoCD check |
| **Total** | **17-26 min** | Complete DEV environment |

## 💰 **Cost Impact**

**Immediate costs start when apply job runs:**
- EKS Control Plane: $73/month ($2.40/day)
- t3.small node: ~$15/month ($0.50/day)
- RDS db.t3.micro: ~$13/month ($0.43/day)
- NAT Gateway: ~$32/month ($1.07/day)
- **Daily cost: ~$4.40/day**

## 🔍 **How to Monitor**

### GitHub Actions UI:
```
1. Go to: https://github.com/chiju/tbyte/actions
2. Click on the running workflow
3. Watch each job progress:
   ├── validate ✅
   ├── security ✅
   ├── plan ✅
   └── apply (in progress...)
```

### AWS Console:
```
1. Switch to DEV account (761380703881)
2. Check EKS console for cluster creation
3. Check EC2 for nodes launching
4. Check RDS for database creation
```

## 🚨 **Possible Issues**

### Common Failures:
- **IAM permissions**: Role assumption fails
- **Resource limits**: Account limits exceeded
- **Network conflicts**: CIDR overlaps
- **Timeout**: EKS cluster takes too long

### Automatic Retries:
- Terraform apply retries 2 times with 30s delay
- EKS access policy propagation handled

## ✅ **Success Indicators**

**Pipeline succeeds when:**
- ✅ All Terraform resources created
- ✅ EKS nodes are Ready
- ✅ ArgoCD pods are Running
- ✅ Post-deployment tests pass

**You'll see:**
```
🎉 dev infrastructure deployed successfully!
Environment: dev
Account: 761380703881
```

## 🎯 **After Success**

**DEV environment will be ready for:**
1. Application deployments via ArgoCD
2. Developer testing and validation
3. Environment promotion to staging
4. Cost monitoring and optimization

**Ready to trigger this automated deployment?**
