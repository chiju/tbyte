# Multi-Account AWS Strategy

## **Current Implementation: Single Account**
- **Production Environment**: All resources in one AWS account
- **Justification**: Assessment focus, cost optimization, time constraints

## **Enterprise Multi-Account Strategy**

### **Account Structure**
```
AWS Organization
├── Management Account (billing, governance)
├── Security Account (logging, monitoring, compliance)
├── Shared Services Account (DNS, CI/CD, container registry)
├── Development Account (dev environments)
├── Staging Account (pre-production testing)
└── Production Account (live workloads)
```

### **Implementation with Terraform**

#### **Account-Specific Variables**
```hcl
# terraform/environments/dev/terraform.tfvars
environment = "dev"
aws_account_id = "111111111111"
cluster_name = "eks-dev"
instance_types = ["t3.small"]
min_nodes = 1
max_nodes = 3

# terraform/environments/staging/terraform.tfvars  
environment = "staging"
aws_account_id = "222222222222"
cluster_name = "eks-staging"
instance_types = ["t3.medium"]
min_nodes = 2
max_nodes = 5

# terraform/environments/prod/terraform.tfvars
environment = "production"
aws_account_id = "333333333333"
cluster_name = "eks-prod"
instance_types = ["t3.large", "t3.xlarge"]
min_nodes = 3
max_nodes = 10
```

#### **Cross-Account IAM Roles**
```hcl
# terraform/modules/cross-account-roles/main.tf
resource "aws_iam_role" "cross_account_deployment" {
  name = "CrossAccountDeploymentRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.shared_services_account}:root",
            "arn:aws:iam::${var.management_account}:role/GitHubActionsRole"
          ]
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deployment_policy" {
  role       = aws_iam_role.cross_account_deployment.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
```

#### **Environment-Specific Deployment**
```bash
# Deploy to Development Account
export AWS_PROFILE=dev-account
cd terraform/environments/dev
terraform init -backend-config="bucket=terraform-state-dev"
terraform apply

# Deploy to Staging Account  
export AWS_PROFILE=staging-account
cd terraform/environments/staging
terraform init -backend-config="bucket=terraform-state-staging"
terraform apply

# Deploy to Production Account
export AWS_PROFILE=prod-account
cd terraform/environments/prod
terraform init -backend-config="bucket=terraform-state-prod"
terraform apply
```

### **GitHub Actions Multi-Account Pipeline**
```yaml
name: Multi-Account Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: development
    steps:
      - name: Configure AWS credentials for Dev
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111111111111:role/GitHubActionsRole
          aws-region: eu-central-1
          
      - name: Deploy to Dev Account
        run: |
          cd terraform/environments/dev
          terraform init
          terraform apply -auto-approve

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Configure AWS credentials for Staging
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::222222222222:role/GitHubActionsRole
          aws-region: eu-central-1
          
      - name: Deploy to Staging Account
        run: |
          cd terraform/environments/staging
          terraform init
          terraform apply -auto-approve

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Configure AWS credentials for Production
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::333333333333:role/GitHubActionsRole
          aws-region: eu-central-1
          
      - name: Deploy to Production Account
        run: |
          cd terraform/environments/prod
          terraform init
          terraform apply -auto-approve
```

### **Benefits of Multi-Account Strategy**

#### **✅ Security Isolation**
- **Blast radius containment**: Issues in dev don't affect prod
- **IAM boundary enforcement**: Clear permission boundaries
- **Compliance**: Easier audit trails and compliance

#### **✅ Cost Management**
- **Account-level billing**: Clear cost attribution
- **Budget controls**: Per-account spending limits
- **Resource tagging**: Environment-specific cost tracking

#### **✅ Operational Benefits**
- **Independent scaling**: Different resource limits per account
- **Service quotas**: Separate limits for each environment
- **Disaster recovery**: Account-level isolation

### **Implementation Costs**

#### **Single Account (Current)**
- **Cost**: ~$175/month
- **Complexity**: Low
- **Management**: Simple

#### **Multi-Account (Enterprise)**
- **Cost**: ~$525/month ($175 × 3 accounts)
- **Complexity**: Medium
- **Management**: AWS Organizations, cross-account roles

### **Migration Path**

#### **Phase 1: Current State**
```
Single Account → All environments in namespaces
```

#### **Phase 2: Account Separation**
```bash
# 1. Create new AWS accounts via Organizations
aws organizations create-account --email dev@company.com --account-name "Development"

# 2. Setup cross-account roles
terraform apply -target=module.cross_account_roles

# 3. Migrate environments one by one
terraform state mv module.eks module.eks_dev
```

#### **Phase 3: Full Multi-Account**
```
Management Account → Security Account → Dev Account → Staging Account → Prod Account
```

### **Current Assessment Decision**

#### **✅ Why Single Account for Assessment:**
1. **Time Constraint**: 3 days vs weeks for multi-account setup
2. **Cost Optimization**: $175 vs $525+ monthly
3. **Focus**: Demonstrate technical capability, not account management
4. **Complexity**: Keep assessment focused on core DevOps skills

#### **✅ Production Recommendation:**
- **Startups**: Single account with namespace separation
- **Scale-ups**: Multi-account when team size > 20
- **Enterprise**: Multi-account mandatory for compliance

### **Code Implementation Ready**
All Terraform modules and GitHub Actions are designed to support multi-account deployment with minimal changes:

```bash
# Current: Single account deployment
terraform apply -var="environment=prod"

# Future: Multi-account deployment  
terraform apply -var="environment=prod" -var="aws_account_id=333333333333"
```

## **Conclusion**
Multi-account strategy is **documented and code-ready** but **not implemented** for assessment efficiency. This demonstrates **enterprise-level thinking** while maintaining **practical delivery focus**.
