# Terraform Troubleshooting Guide (Section C2)

## Error: Cycle detected in resource dependencies

### Problem
```
Error: Cycle: aws_security_group.app, aws_security_group.db
```

### Root Cause Analysis
```bash
# Visualize dependency graph
terraform graph | dot -Tpng > graph.png

# Check resource references
grep -r "aws_security_group.app" *.tf
grep -r "aws_security_group.db" *.tf
```

### Common Causes
- **Circular references**: Security groups referencing each other
- **Module dependencies**: Modules with circular dependencies
- **Data source loops**: Data sources depending on resources that depend on them

### Step-by-Step Fix
```hcl
# BEFORE (Circular dependency)
resource "aws_security_group" "app" {
  name = "app-sg"
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]  # References db
  }
}

resource "aws_security_group" "db" {
  name = "db-sg"
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # References app
  }
}

# AFTER (Fixed with separate rules)
resource "aws_security_group" "app" {
  name = "app-sg"
}

resource "aws_security_group" "db" {
  name = "db-sg"
}

resource "aws_security_group_rule" "app_to_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.app.id
}

resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.db.id
}
```

## Error: IAM role missing permissions

### Problem
```
Error: AccessDenied: User: arn:aws:sts::123456789012:assumed-role/terraform-role/terraform is not authorized to perform: ec2:CreateVpc
```

### Root Cause Analysis
```bash
# Check current IAM identity
aws sts get-caller-identity

# Check attached policies
aws iam list-attached-role-policies --role-name terraform-role

# Simulate policy
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/terraform-role \
  --action-names ec2:CreateVpc \
  --resource-arns "*"
```

### Step-by-Step Fix
```bash
# 1. Identify missing permissions from error message
# Error shows: ec2:CreateVpc

# 2. Check current policy
aws iam get-role-policy --role-name terraform-role --policy-name terraform-policy

# 3. Add missing permissions
aws iam put-role-policy \
  --role-name terraform-role \
  --policy-name terraform-policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:*",
          "iam:*",
          "s3:*",
          "rds:*",
          "eks:*"
        ],
        "Resource": "*"
      }
    ]
  }'

# 4. Verify permissions
terraform plan
```

### Terraform IAM Policy Template
```hcl
resource "aws_iam_role_policy" "terraform_policy" {
  name = "terraform-policy"
  role = aws_iam_role.terraform_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 permissions
          "ec2:*",
          # IAM permissions
          "iam:*",
          # S3 permissions
          "s3:*",
          # RDS permissions
          "rds:*",
          # EKS permissions
          "eks:*",
          # CloudWatch permissions
          "logs:*",
          "cloudwatch:*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## Error: Resource address has changed

### Problem
```
Error: Resource instance aws_instance.web[0] does not exist in the configuration.
```

### Root Cause Analysis
```bash
# Check current state
terraform state list

# Show specific resource
terraform state show aws_instance.web[0]

# Check configuration
grep -r "aws_instance.web" *.tf
```

### Common Causes
- **Resource renamed**: Changed resource name in configuration
- **Count/for_each changes**: Changed from count to for_each or vice versa
- **Module refactoring**: Moved resources between modules
- **Resource type change**: Changed resource type

### Step-by-Step Fix

#### Option 1: State Move
```bash
# Move resource in state to match new configuration
terraform state mv aws_instance.web[0] aws_instance.app[0]

# Verify the move
terraform state list
terraform plan
```

#### Option 2: Import Resource
```bash
# Remove from state
terraform state rm aws_instance.web[0]

# Import with new address
terraform import aws_instance.app[0] i-1234567890abcdef0

# Verify import
terraform plan
```

#### Option 3: Refactor with moved block (Terraform 1.1+)
```hcl
# Add moved block to configuration
moved {
  from = aws_instance.web[0]
  to   = aws_instance.app[0]
}

# Apply the move
terraform plan
terraform apply
```

### Complex State Management
```bash
# Backup state before changes
terraform state pull > terraform.tfstate.backup

# List all resources
terraform state list

# Show resource details
terraform state show aws_instance.web

# Remove resource from state (doesn't destroy)
terraform state rm aws_instance.web

# Replace provider
terraform state replace-provider hashicorp/aws registry.terraform.io/hashicorp/aws
```

## State Inspection and Drift Detection

### Check for Configuration Drift
```bash
# Compare current state with actual infrastructure
terraform plan -detailed-exitcode

# Refresh state from actual infrastructure
terraform apply -refresh-only

# Show differences
terraform show -json | jq '.values.root_module.resources'
```

### State File Issues
```bash
# Validate state file
terraform validate

# Check state file integrity
terraform state list

# Recover from corrupted state
terraform force-unlock <lock-id>

# Import existing resources
terraform import aws_instance.web i-1234567890abcdef0
```

### Remote State Issues
```bash
# Initialize with existing state
terraform init -reconfigure

# Migrate state backend
terraform init -migrate-state

# Check backend configuration
terraform init -backend-config="bucket=my-terraform-state"
```

## Module-Related Issues

### Module Source Changes
```bash
# Update module sources
terraform get -update

# Reinitialize after module changes
terraform init -upgrade

# Check module versions
terraform version
```

### Module State Issues
```hcl
# Move resources between modules
moved {
  from = aws_instance.web
  to   = module.web.aws_instance.server
}
```

## Provider Issues

### Provider Version Conflicts
```bash
# Lock provider versions
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64

# Upgrade providers
terraform init -upgrade

# Check provider requirements
terraform providers
```

### Provider Configuration
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}
```

## Performance and Debugging

### Enable Debug Logging
```bash
# Enable detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Run terraform command
terraform plan

# Analyze logs
grep -i error terraform.log
```

### Parallel Execution Issues
```bash
# Reduce parallelism
terraform apply -parallelism=1

# Target specific resources
terraform apply -target=aws_instance.web
```

### Large State Files
```bash
# Use partial configuration
terraform plan -target=module.vpc

# Split large configurations
terraform workspace new production
terraform workspace select production
```

## Recovery Procedures

### Disaster Recovery
```bash
# 1. Backup everything
terraform state pull > backup.tfstate
cp terraform.tfstate terraform.tfstate.backup
cp -r .terraform .terraform.backup

# 2. Restore from backup
cp backup.tfstate terraform.tfstate
terraform init

# 3. Verify and reconcile
terraform plan
terraform apply
```

### State Corruption Recovery
```bash
# 1. Check state file
terraform state list

# 2. If corrupted, restore from backup
aws s3 cp s3://my-terraform-state/terraform.tfstate ./terraform.tfstate

# 3. Reinitialize
terraform init
terraform plan
```

### Lock Issues
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>

# Check lock status
terraform state list
```

## Best Practices for Prevention

### State Management
```hcl
# Use remote state with locking
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Resource Organization
```hcl
# Use consistent naming
resource "aws_instance" "web_server" {
  # Use descriptive names
  tags = {
    Name = "${var.environment}-web-server"
  }
}

# Group related resources
module "vpc" {
  source = "./modules/vpc"
}

module "eks" {
  source = "./modules/eks"
  vpc_id = module.vpc.vpc_id
}
```

### Validation and Testing
```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan before apply
terraform plan -out=tfplan
terraform apply tfplan

# Use workspaces for environments
terraform workspace new staging
terraform workspace new production
```
