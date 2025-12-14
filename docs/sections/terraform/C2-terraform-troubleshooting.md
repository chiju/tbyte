# C2 — Troubleshoot a Broken Terraform Deployment

## Problem

**Scenario**: Production Terraform deployment experiencing critical failures that prevent infrastructure updates and deployments:

1. **Cycle Detected Error** - Terraform cannot resolve resource dependencies
2. **IAM Role Missing Permissions** - Authentication and authorization failures
3. **Resource Address Has Changed** - State file inconsistencies and resource drift
4. **State Corruption** - Terraform state file integrity issues
5. **Configuration Drift** - Infrastructure changes outside of Terraform

**Business Impact**: Infrastructure deployments blocked, unable to scale resources, security vulnerabilities from manual changes, potential service outages.

## Approach

**Systematic Terraform Troubleshooting Methodology:**

1. **Error Analysis**: Identify root cause from Terraform error messages and logs
2. **State Inspection**: Examine Terraform state file for inconsistencies
3. **Configuration Review**: Validate Terraform configuration syntax and logic
4. **Dependency Resolution**: Fix circular dependencies and resource relationships
5. **Permission Validation**: Verify IAM roles and policies
6. **State Recovery**: Repair or rebuild corrupted state files
7. **Drift Remediation**: Align actual infrastructure with desired state

**Tools Used:**
- `terraform plan/apply` for deployment operations
- `terraform state` commands for state management
- `terraform import` for bringing existing resources under management
- AWS CLI for infrastructure inspection and IAM validation

## Solution

### 1. Cycle Detected Error

#### Problem Analysis
```bash
# Symptom: Terraform cannot resolve dependencies
terraform plan

# Error Output:
Error: Cycle: aws_security_group.eks_nodes, aws_eks_cluster.main, 
aws_security_group_rule.eks_cluster_ingress, aws_security_group.eks_cluster
```

#### Root Cause Investigation
```bash
# Analyze dependency graph
terraform graph | dot -Tsvg > dependency_graph.svg

# Common causes:
# 1. Circular security group references
# 2. Resource A depends on B, B depends on A
# 3. Implicit dependencies creating loops
```

#### Step-by-Step Fix
```hcl
# Before (Problematic): Circular dependency
resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]  # Depends on nodes SG
  }
}

resource "aws_security_group" "eks_nodes" {
  name_prefix = "eks-nodes-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]  # Depends on cluster SG
  }
}
```

```hcl
# After (Fixed): Break circular dependency with separate rules
resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  vpc_id      = aws_vpc.main.id
  # No inline rules - use separate resources
}

resource "aws_security_group" "eks_nodes" {
  name_prefix = "eks-nodes-"
  vpc_id      = aws_vpc.main.id
  # No inline rules - use separate resources
}

# Separate security group rules to break cycle
resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "nodes_egress_to_cluster" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}
```

#### Validation
```bash
# Verify cycle is resolved
terraform plan
# Should complete without cycle errors

# Check dependency graph
terraform graph | grep -E "(eks_cluster|eks_nodes)"
```

### 2. IAM Role Missing Permissions

#### Problem Analysis
```bash
# Symptom: Permission denied errors during deployment
terraform apply

# Error Output:
Error: error creating EKS Cluster: AccessDenied: User: arn:aws:sts::045129524082:assumed-role/github-actions-role/GitHubActions 
is not authorized to perform: eks:CreateCluster on resource: arn:aws:eks:eu-central-1:045129524082:cluster/tbyte-dev
```

#### Root Cause Investigation
```bash
# Check current IAM identity
aws sts get-caller-identity --profile dev_4082

# Check role permissions
aws iam get-role --profile dev_4082 --role-name github-actions-role

# List attached policies
aws iam list-attached-role-policies --profile dev_4082 --role-name github-actions-role

# Check policy permissions
aws iam get-policy-version --profile dev_4082 \
  --policy-arn arn:aws:iam::045129524082:policy/github-actions-policy \
  --version-id v1
```

#### Step-by-Step Fix

**1. Identify Missing Permissions**
```bash
# Analyze the specific error
# Error: eks:CreateCluster - Need EKS permissions
# Error: iam:PassRole - Need to pass service roles
# Error: ec2:CreateVpc - Need VPC permissions
```

**2. Update IAM Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:DescribeCluster",
        "eks:UpdateClusterConfig",
        "eks:DeleteCluster",
        "eks:ListClusters",
        "eks:TagResource",
        "eks:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/tbyte-*-cluster-role",
        "arn:aws:iam::*:role/tbyte-*-node-role"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:CreateSubnet",
        "ec2:CreateInternetGateway",
        "ec2:CreateNatGateway",
        "ec2:CreateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    }
  ]
}
```

**3. Apply Policy Update**
```bash
# Update the policy
aws iam put-role-policy --profile dev_4082 \
  --role-name github-actions-role \
  --policy-name terraform-permissions \
  --policy-document file://terraform-policy.json

# Verify policy is attached
aws iam get-role-policy --profile dev_4082 \
  --role-name github-actions-role \
  --policy-name terraform-permissions
```

#### Validation
```bash
# Test permissions with dry run
terraform plan

# Should complete without permission errors
```

### 3. Resource Address Has Changed

#### Problem Analysis
```bash
# Symptom: Terraform cannot find resources in state
terraform plan

# Error Output:
Error: Resource targeting is required
│ The configuration no longer contains module.vpc.aws_subnet.private, but it is in the Terraform state.
│ Please run 'terraform state rm module.vpc.aws_subnet.private' or include it in a required_providers block.
```

#### Root Cause Investigation
```bash
# Inspect current state
terraform state list

# Check specific resource
terraform state show 'module.vpc.aws_subnet.private[0]'

# Compare with configuration
grep -r "aws_subnet" *.tf

# Common causes:
# 1. Resource renamed in configuration
# 2. Module structure changed
# 3. Resource moved between modules
# 4. Count/for_each changes
```

#### Step-by-Step Fix

**Scenario 1: Resource Renamed**
```bash
# Old resource name in state: aws_subnet.private
# New resource name in config: aws_subnet.private_subnet

# Move resource in state
terraform state mv 'aws_subnet.private[0]' 'aws_subnet.private_subnet[0]'
terraform state mv 'aws_subnet.private[1]' 'aws_subnet.private_subnet[1]'

# Verify move
terraform state list | grep subnet
```

**Scenario 2: Module Structure Changed**
```bash
# Resource moved from root to module
# Old: aws_vpc.main
# New: module.networking.aws_vpc.main

# Move to module
terraform state mv 'aws_vpc.main' 'module.networking.aws_vpc.main'

# Verify
terraform state show 'module.networking.aws_vpc.main'
```

**Scenario 3: Count to For_Each Migration**
```hcl
# Before: Using count
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  cidr_block        = cidrsubnet(var.cidr, 4, count.index + 16)
  availability_zone = var.availability_zones[count.index]
}

# After: Using for_each
resource "aws_subnet" "private" {
  for_each          = toset(var.availability_zones)
  cidr_block        = cidrsubnet(var.cidr, 4, index(var.availability_zones, each.value) + 16)
  availability_zone = each.value
}
```

```bash
# Migration commands
terraform state mv 'aws_subnet.private[0]' 'aws_subnet.private["eu-central-1a"]'
terraform state mv 'aws_subnet.private[1]' 'aws_subnet.private["eu-central-1b"]'

# Verify migration
terraform plan
# Should show no changes if migration is correct
```

#### Validation
```bash
# Verify state consistency
terraform plan
# Should show "No changes" if addresses are fixed

# Double-check state
terraform state list
```

### 4. State File Corruption and Recovery

#### Problem Analysis
```bash
# Symptom: State file corruption or inconsistency
terraform plan

# Error Output:
Error: Failed to load state: state snapshot was created by Terraform v1.6.0, which is newer than current v1.5.0
# OR
Error: state file corrupt: unexpected EOF
```

#### Root Cause Investigation
```bash
# Check state file integrity
terraform state pull > current_state.json

# Validate JSON format
jq . current_state.json > /dev/null && echo "Valid JSON" || echo "Corrupted JSON"

# Check Terraform version compatibility
terraform version

# Check remote state backend
aws s3 ls s3://tbyte-terragrunt-state-045129524082/environments/dev/vpc/ --profile dev_4082
```

#### Step-by-Step Recovery

**Option 1: Restore from Backup**
```bash
# List available state versions (S3 versioning)
aws s3api list-object-versions --profile dev_4082 \
  --bucket tbyte-terragrunt-state-045129524082 \
  --prefix environments/dev/vpc/terraform.tfstate

# Download previous version
aws s3api get-object --profile dev_4082 \
  --bucket tbyte-terragrunt-state-045129524082 \
  --key environments/dev/vpc/terraform.tfstate \
  --version-id <version-id> \
  backup_state.json

# Restore backup
terraform state push backup_state.json
```

**Option 2: Rebuild State from Existing Infrastructure**
```bash
# Remove corrupted state
terraform state rm $(terraform state list)

# Import existing resources
terraform import aws_vpc.main vpc-0f0359687a44abb93
terraform import 'aws_subnet.public[0]' subnet-04a89811efb0791f3
terraform import 'aws_subnet.public[1]' subnet-0654a2e830b7771fc
terraform import 'aws_subnet.private[0]' subnet-08751bdda9f457a1c
terraform import 'aws_subnet.private[1]' subnet-0369220437e24cd48

# Verify import
terraform plan
# Should show minimal or no changes
```

**Option 3: Force Unlock (if locked)**
```bash
# Check lock status
terraform force-unlock <lock-id>

# If using Terragrunt
terragrunt force-unlock <lock-id>
```

### 5. Configuration Drift Detection and Remediation

#### Problem Analysis
```bash
# Symptom: Infrastructure differs from Terraform state
terraform plan

# Output shows unexpected changes:
# ~ aws_security_group.eks_cluster will be updated in-place
#   ~ ingress {
#     - cidr_blocks = ["10.0.0.0/8"] -> null
#     + cidr_blocks = ["10.0.0.0/16"]
#   }
```

#### Root Cause Investigation
```bash
# Check actual AWS resources
aws ec2 describe-security-groups --profile dev_4082 --region eu-central-1 \
  --group-ids sg-0366406ec2fb833cb

# Compare with Terraform state
terraform state show aws_security_group.eks_cluster

# Check CloudTrail for manual changes
aws logs filter-log-events --profile dev_4082 --region eu-central-1 \
  --log-group-name CloudTrail/EKSClusterLogs \
  --start-time $(date -d '24 hours ago' +%s)000
```

#### Step-by-Step Remediation

**Option 1: Accept Drift (Update Configuration)**
```hcl
# Update Terraform configuration to match current state
resource "aws_security_group" "eks_cluster" {
  name_prefix = "eks-cluster-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Accept the manual change
  }
}
```

**Option 2: Revert Drift (Restore Desired State)**
```bash
# Apply Terraform to revert manual changes
terraform apply

# This will change the security group back to desired state
```

**Option 3: Import and Reconcile**
```bash
# Remove from state and re-import
terraform state rm aws_security_group.eks_cluster
terraform import aws_security_group.eks_cluster sg-0366406ec2fb833cb

# Then update configuration to match imported state
terraform plan
```

#### Drift Prevention
```bash
# Enable CloudTrail for audit logging
# Set up CloudWatch alarms for infrastructure changes
# Implement policy to prevent manual changes
# Regular drift detection in CI/CD pipeline

# Automated drift detection
terraform plan -detailed-exitcode
# Exit code 2 indicates changes detected
```

## Result

### Troubleshooting Success Metrics

#### Issue Resolution Summary
1. **Cycle Detection**: Resolved by breaking circular dependencies with separate security group rules
2. **IAM Permissions**: Fixed by adding comprehensive EKS and EC2 permissions to GitHub Actions role
3. **Resource Addressing**: Corrected using `terraform state mv` commands for renamed resources
4. **State Corruption**: Recovered using S3 versioning and selective resource import
5. **Configuration Drift**: Remediated through state reconciliation and configuration updates

#### Real-World Examples from TByte Infrastructure

**Cycle Resolution Applied:**
```bash
# Successfully deployed EKS cluster after fixing security group cycles
aws eks describe-cluster --profile dev_4082 --region eu-central-1 --name tbyte-dev
# Status: ACTIVE
```

**Permission Fix Verified:**
```bash
# GitHub Actions role now has proper EKS permissions
aws iam get-role-policy --profile dev_4082 --role-name github-actions-role --policy-name terraform-permissions
# Policy includes eks:CreateCluster, iam:PassRole, ec2:* permissions
```

**State Management Success:**
```bash
# State file integrity maintained across deployments
terraform state list | wc -l
# Shows all resources properly tracked in state
```

### Troubleshooting Toolkit

#### Essential Commands Reference
```bash
# State Management
terraform state list                    # List all resources in state
terraform state show <resource>         # Show resource details
terraform state mv <old> <new>         # Move/rename resource
terraform state rm <resource>          # Remove from state
terraform state pull                   # Download current state
terraform state push <file>           # Upload state file

# Import and Recovery
terraform import <resource> <id>       # Import existing resource
terraform force-unlock <lock-id>      # Force unlock state
terraform refresh                     # Update state from real infrastructure

# Debugging
terraform plan -detailed-exitcode     # Exit code indicates changes
terraform graph                       # Generate dependency graph
terraform validate                    # Validate configuration syntax
terraform fmt -check -diff           # Check formatting
```

#### Preventive Measures Implemented

**1. State Protection**
```hcl
# S3 backend with versioning and locking
terraform {
  backend "s3" {
    bucket         = "tbyte-terragrunt-state-045129524082"
    key            = "environments/dev/vpc/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terragrunt-lock-table"
  }
}
```

**2. CI/CD Validation**
```yaml
# GitHub Actions pipeline includes validation
- name: Terraform Validate
  run: terraform validate

- name: Terraform Plan
  run: terraform plan -detailed-exitcode
```

**3. Drift Detection**
```bash
# Automated drift detection in pipeline
terraform plan -detailed-exitcode
if [ $? -eq 2 ]; then
  echo "Configuration drift detected!"
  # Send alert or create issue
fi
```

### Risk Mitigation Strategies

#### State File Protection
- **S3 Versioning**: Automatic backup of all state changes
- **DynamoDB Locking**: Prevents concurrent modifications
- **Encryption**: State files encrypted at rest and in transit
- **Access Control**: IAM policies restrict state file access

#### Configuration Management
- **Code Reviews**: All Terraform changes require PR approval
- **Automated Testing**: Validation and security scanning in CI/CD
- **Module Standards**: Consistent patterns across all modules
- **Documentation**: Clear dependency relationships documented

#### Monitoring and Alerting
- **CloudTrail Integration**: Track all infrastructure changes
- **Drift Detection**: Regular comparison of desired vs actual state
- **Performance Monitoring**: Track deployment success rates and times
- **Error Alerting**: Immediate notification of deployment failures

### Cost Impact of Issues
- **Deployment Delays**: ~2-4 hours per cycle/permission issue
- **State Recovery**: ~1-2 hours for backup restoration
- **Drift Remediation**: ~30 minutes to 2 hours depending on scope
- **Prevention Investment**: ~1 day setup saves 10+ hours of troubleshooting

### Lessons Learned
1. **Dependency Design**: Always design resources to avoid circular dependencies
2. **Permission Planning**: Grant comprehensive permissions upfront rather than iterative fixes
3. **State Hygiene**: Regular state file validation and backup verification
4. **Change Control**: Strict policies against manual infrastructure changes
5. **Monitoring**: Proactive drift detection prevents larger issues
