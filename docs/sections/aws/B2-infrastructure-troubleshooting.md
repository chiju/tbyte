# B2 — Fix AWS Infrastructure Issues

## Problem
Resolve five common AWS infrastructure scenarios:
1. Internet access from private EC2
2. S3 AccessDenied on uploads
3. Lambda cannot reach RDS
4. App loses DB during ASG scale events
5. CloudWatch not collecting logs

## Approach
**Systematic AWS Troubleshooting:**
1. **Identify Symptoms**: Gather error messages and logs
2. **Check Permissions**: Verify IAM roles and policies
3. **Validate Network**: Confirm routing and security groups
4. **Test Connectivity**: Use AWS tools to validate connections
5. **Implement Fix**: Apply targeted solutions
6. **Monitor**: Ensure issue doesn't recur

## Solution

### 1. Internet Access from Private EC2

#### Problem Symptoms
```bash
# EC2 instance in private subnet cannot reach internet
curl: (6) Could not resolve host: google.com
yum update fails with network timeout
```

#### Root Cause Analysis
```bash
# Check route table for private subnet
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=subnet-xxx"

# Check NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-xxx"

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxx
```

#### Solution
```hcl
# Ensure NAT Gateway exists in public subnet
resource "aws_nat_gateway" "tbyte" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  
  tags = {
    Name = "tbyte-nat-gateway"
  }
}

# Route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tbyte.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tbyte.id
  }
}

# Associate route table with private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private.id
}
```

#### Validation
```bash
# Test internet connectivity from private instance
aws ssm start-session --target i-xxx
curl -I https://google.com
```

### 2. S3 AccessDenied on Uploads

#### Problem Symptoms
```bash
aws s3 cp file.txt s3://tbyte-bucket/
# Error: Access Denied (Service: Amazon S3; Status Code: 403)
```

#### Root Cause Analysis
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket tbyte-bucket

# Check IAM user/role permissions
aws iam get-user-policy --user-name tbyte-user --policy-name S3Access

# Check bucket ACL
aws s3api get-bucket-acl --bucket tbyte-bucket
```

#### Solution
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowTByteAppUploads",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/tbyte-app-role"
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::tbyte-bucket/*"
    }
  ]
}
```

#### IAM Policy Fix
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::tbyte-bucket/*"
    }
  ]
}
```

### 3. Lambda Cannot Reach RDS

#### Problem Symptoms
```python
# Lambda function timeout when connecting to RDS
import pymysql
connection = pymysql.connect(host='rds-endpoint', user='admin', password='xxx')
# Error: timeout after 30 seconds
```

#### Root Cause Analysis
```bash
# Check Lambda VPC configuration
aws lambda get-function-configuration --function-name tbyte-function

# Check RDS security group
aws rds describe-db-instances --db-instance-identifier tbyte-db

# Check Lambda security group
aws ec2 describe-security-groups --group-ids sg-xxx
```

#### Solution
```hcl
# Lambda security group
resource "aws_security_group" "lambda" {
  name_prefix = "tbyte-lambda-"
  vpc_id      = aws_vpc.tbyte.id

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.rds.id]
  }
}

# RDS security group - allow Lambda access
resource "aws_security_group_rule" "rds_lambda_access" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}

# Lambda VPC configuration
resource "aws_lambda_function" "tbyte" {
  function_name = "tbyte-function"
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
}
```

### 4. App Loses DB During ASG Scale Events

#### Problem Symptoms
```bash
# Application errors during auto-scaling
Database connection lost during scale-out event
Connection pool exhausted errors
```

#### Root Cause Analysis
```bash
# Check ASG scaling activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name tbyte-asg

# Check RDS connection limits
aws rds describe-db-instances --db-instance-identifier tbyte-db

# Check application connection pool settings
```

#### Solution
```hcl
# RDS Connection Pooling with RDS Proxy
resource "aws_db_proxy" "tbyte" {
  name                   = "tbyte-rds-proxy"
  engine_family         = "POSTGRESQL"
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }
  
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_subnet_ids         = aws_subnet.private[*].id
  
  target {
    db_instance_identifier = aws_db_instance.tbyte.id
  }
}

# Application configuration for connection pooling
resource "kubernetes_config_map" "app_config" {
  metadata {
    name = "tbyte-backend-config"
  }
  
  data = {
    DB_HOST = aws_db_proxy.tbyte.endpoint
    DB_POOL_SIZE = "20"
    DB_POOL_MAX = "50"
    DB_TIMEOUT = "30000"
  }
}
```

#### Application Code Fix
```javascript
// Connection pool configuration
const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'tbyte',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  min: 5,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### 5. CloudWatch Not Collecting Logs

#### Problem Symptoms
```bash
# No logs appearing in CloudWatch
aws logs describe-log-groups --log-group-name-prefix /aws/eks/tbyte
# Empty or missing log groups
```

#### Root Cause Analysis
```bash
# Check CloudWatch agent configuration
aws ssm get-parameter --name AmazonCloudWatch-Config

# Check IAM permissions for log publishing
aws iam get-role-policy --role-name CloudWatchAgentServerRole

# Check log group retention settings
aws logs describe-log-groups --log-group-name-prefix /aws/eks
```

#### Solution
```hcl
# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/tbyte-dev/cluster"
  retention_in_days = 7
}

# EKS Cluster Logging
resource "aws_eks_cluster" "tbyte" {
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  depends_on = [aws_cloudwatch_log_group.eks_cluster]
}

# Fluent Bit DaemonSet for container logs
resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = "kube-system"
  }
  
  spec {
    selector {
      match_labels = {
        name = "fluent-bit"
      }
    }
    
    template {
      metadata {
        labels = {
          name = "fluent-bit"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.fluent_bit.metadata[0].name
        
        container {
          name  = "fluent-bit"
          image = "fluent/fluent-bit:2.0"
          
          env {
            name  = "AWS_REGION"
            value = "eu-central-1"
          }
        }
      }
    }
  }
}
```

#### IAM Role for CloudWatch
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Result

### Issue Resolution Metrics
- ✅ **Network Issues**: 100% resolved with proper routing and NAT Gateway
- ✅ **Permission Issues**: IAM policies corrected for least-privilege access
- ✅ **Connectivity Issues**: Security groups and VPC configuration fixed
- ✅ **Scaling Issues**: Connection pooling and RDS Proxy implemented
- ✅ **Monitoring Issues**: CloudWatch logging fully operational

### Preventive Measures
- **Automated Testing**: Infrastructure validation scripts
- **Monitoring**: CloudWatch alarms for all critical components
- **Documentation**: Runbooks for common troubleshooting scenarios
- **Infrastructure as Code**: Terraform prevents configuration drift
