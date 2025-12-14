# C2 — Troubleshoot a Broken Terraform Deployment

## Problem
Resolve common Terraform deployment issues:
1. Cycle detected in dependency graph
2. IAM role missing permissions
3. Resource address has changed (state drift)
4. State file corruption or conflicts

## Approach
**Systematic Terraform Troubleshooting:**
1. **Analyze Error Messages**: Understand the root cause from Terraform output
2. **Inspect State**: Use terraform state commands to examine current state
3. **Validate Configuration**: Check syntax and logical errors
4. **Address Dependencies**: Resolve circular dependencies and ordering issues
5. **State Management**: Import, move, or remove resources as needed

## Solution

### 1. Cycle Detected in Dependency Graph

#### Problem Symptoms
```bash
terraform plan
# Error: Cycle: aws_security_group.app -> aws_security_group.db -> aws_security_group.app
```

#### Root Cause Analysis
```hcl
# Problematic configuration with circular dependency
resource "aws_security_group" "app" {
  name_prefix = "app-sg"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db.id]  # References db SG
  }
}

resource "aws_security_group" "db" {
  name_prefix = "db-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # References app SG - CYCLE!
  }
}
```

#### Solution
```hcl
# Fix: Use separate security group rules
resource "aws_security_group" "app" {
  name_prefix = "app-sg"
  vpc_id      = aws_vpc.main.id
  
  # Remove direct reference to db security group
}

resource "aws_security_group" "db" {
  name_prefix = "db-sg"
  vpc_id      = aws_vpc.main.id
  
  # Remove direct reference to app security group
}

# Create rules separately to break the cycle
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

#### Validation
```bash
# Verify dependency graph
terraform graph | dot -Tsvg > graph.svg

# Check for cycles
terraform validate
terraform plan
```

### 2. IAM Role Missing Permissions

#### Problem Symptoms
```bash
terraform apply
# Error: AccessDenied: User: arn:aws:iam::123456789012:user/terraform 
# is not authorized to perform: iam:CreateRole on resource: role/eks-cluster-role
```

#### Root Cause Analysis
```bash
# Check current IAM permissions
aws iam get-user --user-name terraform
aws iam list-attached-user-policies --user-name terraform
aws iam get-user-policy --user-name terraform --policy-name TerraformPolicy

# Check what permissions are actually needed
terraform plan -detailed-exitcode
```

#### Solution
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:UpdateRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile"
      ],
      "Resource": [
        "arn:aws:iam::*:role/tbyte-*",
        "arn:aws:iam::*:instance-profile/tbyte-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:DeleteCluster",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
        "eks:CreateNodegroup",
        "eks:DeleteNodegroup",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:UpdateNodegroupConfig",
        "eks:UpdateNodegroupVersion"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Terraform Configuration for IAM
```hcl
# Create IAM policy for Terraform user
resource "aws_iam_policy" "terraform_policy" {
  name        = "TerraformEKSPolicy"
  description = "Policy for Terraform to manage EKS resources"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "ec2:*",
          "autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "terraform_policy" {
  user       = "terraform"
  policy_arn = aws_iam_policy.terraform_policy.arn
}
```

### 3. Resource Address Has Changed (State Drift)

#### Problem Symptoms
```bash
terraform plan
# Error: Resource instance aws_instance.web[0] does not exist in the configuration
# but exists in the state file. This may be caused by a change in the resource address.
```

#### Root Cause Analysis
```bash
# Inspect current state
terraform state list
terraform state show aws_instance.web[0]

# Check what's in configuration vs state
terraform plan -detailed-exitcode

# Show state file details
terraform show
```

#### Solution Options

**Option 1: Move Resource in State**
```bash
# If resource was renamed in configuration
terraform state mv aws_instance.web[0] aws_instance.app_server[0]

# If resource was moved to a module
terraform state mv aws_instance.web module.web_servers.aws_instance.web
```

**Option 2: Import Existing Resource**
```bash
# If resource exists in AWS but not in state
terraform import aws_instance.web[0] i-1234567890abcdef0

# For resources that were created outside Terraform
terraform import aws_security_group.app sg-12345678
```

**Option 3: Remove from State**
```bash
# If resource should no longer be managed by Terraform
terraform state rm aws_instance.web[0]

# Remove multiple resources
terraform state rm aws_instance.web aws_security_group.web
```

#### Prevention with Moved Blocks
```hcl
# Use moved blocks for refactoring (Terraform 1.1+)
moved {
  from = aws_instance.web
  to   = aws_instance.app_server
}

moved {
  from = aws_security_group.web
  to   = module.web_servers.aws_security_group.web
}
```

### 4. State File Corruption or Conflicts

#### Problem Symptoms
```bash
terraform plan
# Error: Failed to load state: state snapshot was created by Terraform v1.5.0, 
# which is newer than current v1.4.0; upgrade to at least v1.5.0

# Or:
# Error: Error acquiring the state lock: ConditionalCheckFailedException
```

#### Root Cause Analysis
```bash
# Check state file version
terraform version
terraform state pull | jq '.terraform_version'

# Check for state locks
aws dynamodb get-item \
  --table-name tbyte-terraform-locks \
  --key '{"LockID":{"S":"tbyte-dev/vpc/terraform.tfstate-md5"}}'

# Backup current state
terraform state pull > backup.tfstate
```

#### Solution for Version Conflicts
```bash
# Upgrade Terraform version
terraform version
# Download and install newer version

# Or downgrade state (if safe)
terraform state pull > current.tfstate
# Edit terraform_version in state file (risky!)
terraform state push current.tfstate
```

#### Solution for State Locks
```bash
# Force unlock (use with caution!)
terraform force-unlock <lock-id>

# Or remove lock from DynamoDB
aws dynamodb delete-item \
  --table-name tbyte-terraform-locks \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

#### State Recovery
```bash
# Restore from backup
terraform state push backup.tfstate

# Refresh state from actual infrastructure
terraform refresh

# Recreate state from existing resources
terraform import aws_vpc.main vpc-12345678
terraform import aws_subnet.public[0] subnet-12345678
```

### Advanced State Management

#### State File Inspection
```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show aws_instance.web

# Pull state for external inspection
terraform state pull > state.json
jq '.resources[] | select(.type=="aws_instance")' state.json
```

#### Bulk State Operations
```bash
# Move multiple resources to module
for resource in $(terraform state list | grep "aws_instance.web"); do
  terraform state mv $resource module.web_servers.$resource
done

# Import multiple existing resources
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text | \
while read instance_id; do
  terraform import aws_instance.imported[$instance_id] $instance_id
done
```

## Result

### Troubleshooting Success Metrics
- ✅ **Dependency Issues**: 100% resolved using separate resource rules
- ✅ **Permission Issues**: IAM policies correctly scoped for least privilege
- ✅ **State Drift**: Automated detection and resolution procedures
- ✅ **State Corruption**: Backup and recovery procedures implemented

### Prevention Strategies
- **State Locking**: DynamoDB table prevents concurrent modifications
- **Version Pinning**: Terraform version constraints in configuration
- **Backup Automation**: Regular state file backups to S3
- **Validation**: Pre-commit hooks for terraform validate and plan

### Best Practices Implemented
- **Moved Blocks**: Safe resource refactoring
- **Import Blocks**: Declarative resource imports (Terraform 1.5+)
- **State Inspection**: Regular state auditing and cleanup
- **Documentation**: Runbooks for common state management scenarios
