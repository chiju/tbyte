# GitHub Environment Protection Setup

## **Create Protected Environments**

### **1. Go to Repository Settings**
```
GitHub Repo → Settings → Environments → New Environment
```

### **2. Create Three Environments**

#### **Development Environment**
- **Name**: `development`
- **Protection Rules**: None (auto-deploy)
- **Secrets**: None needed

#### **Staging Environment**  
- **Name**: `staging`
- **Protection Rules**:
  - ✅ **Required reviewers**: 1 person
  - ✅ **Wait timer**: 0 minutes
- **Deployment branches**: `main` only

#### **Production Environment**
- **Name**: `production` 
- **Protection Rules**:
  - ✅ **Required reviewers**: 2 people
  - ✅ **Wait timer**: 5 minutes
  - ✅ **Prevent self-review**: Yes
- **Deployment branches**: `main` only

## **How It Works**

### **Automatic Flow:**
```
PR → Dev (auto) → Merge → Staging (1 approval) → Production (2 approvals + 5min wait)
```

### **Protection in Action:**
1. **Dev**: Deploys automatically on PR
2. **Staging**: Requires 1 approval after main merge
3. **Production**: Requires 2 approvals + 5 minute delay

### **GitHub UI Steps:**

#### **Step 1: Create Environments**
```
Repo → Settings → Environments → New environment
Name: development
[Create environment]

Name: staging  
[Create environment]

Name: production
[Create environment]
```

#### **Step 2: Configure Staging Protection**
```
staging environment → Configure environment
✅ Required reviewers: [Select 1 person]
✅ Deployment branches: Selected branches → main
[Save protection rules]
```

#### **Step 3: Configure Production Protection**
```
production environment → Configure environment  
✅ Required reviewers: [Select 2 people]
✅ Wait timer: 5 minutes
✅ Prevent self-review: Yes
✅ Deployment branches: Selected branches → main
[Save protection rules]
```

## **Pipeline Behavior**

### **Pull Request (Dev Deploy)**
```yaml
deploy-dev:
  if: github.event_name == 'pull_request'
  environment: development  # No protection
```

### **Main Branch (Staging Deploy)**
```yaml
deploy-staging:
  if: github.ref == 'refs/heads/main'
  environment: staging      # 1 approval required
```

### **Production Deploy**
```yaml
deploy-production:
  needs: [deploy-staging]
  environment: production   # 2 approvals + 5min wait
```

## **Testing the Pipeline**

### **1. Create Feature Branch**
```bash
git checkout -b feature/test-pipeline
echo "test" >> README.md
git add . && git commit -m "Test pipeline"
git push origin feature/test-pipeline
```

### **2. Create Pull Request**
```bash
gh pr create --title "Test Environment Pipeline"
# This triggers DEV deployment automatically
```

### **3. Merge to Main**
```bash
gh pr merge --merge
# This triggers STAGING deployment (needs 1 approval)
```

### **4. Production Deployment**
```bash
# After staging approval, PRODUCTION deployment starts
# Requires 2 approvals + 5 minute wait
```

## **Current Status**
- ✅ **Pipeline Code**: Ready in `.github/workflows/environment-promotion-simple.yml`
- ❌ **GitHub Environments**: Need to be created manually
- ❌ **Protection Rules**: Need to be configured manually

## **Quick Setup (5 minutes)**
1. Go to repo Settings → Environments
2. Create 3 environments (development, staging, production)
3. Add protection rules to staging (1 reviewer) and production (2 reviewers)
4. Test with a PR

**Result**: Full environment promotion with approval gates! 🎯
