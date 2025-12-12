# AWS Infrastructure Troubleshooting Guide (Section B2)

## Scenario 1: Internet access from private EC2

### Problem
EC2 instances in private subnets cannot reach the internet.

### Root Cause Analysis
```bash
# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-12345"

# Check NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-12345"

# Check security groups
aws ec2 describe-security-groups --group-ids sg-12345
```

### Common Causes
- **Missing NAT Gateway**: No NAT Gateway in public subnet
- **Route table misconfiguration**: Private subnet not routed to NAT Gateway
- **Security group rules**: Outbound traffic blocked
- **NACL restrictions**: Network ACL blocking traffic

### Exact Fix
```bash
# 1. Create NAT Gateway (if missing)
aws ec2 create-nat-gateway \
  --subnet-id subnet-12345 \
  --allocation-id eipalloc-12345

# 2. Update route table
aws ec2 create-route \
  --route-table-id rtb-12345 \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-12345

# 3. Fix security group
aws ec2 authorize-security-group-egress \
  --group-id sg-12345 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### Terraform Fix
```hcl
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "NAT Gateway"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}
```

## Scenario 2: S3 AccessDenied on uploads

### Problem
Application receives AccessDenied errors when uploading to S3.

### Root Cause Analysis
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket my-bucket

# Check IAM role permissions
aws iam get-role-policy --role-name MyRole --policy-name MyPolicy

# Check bucket ACL
aws s3api get-bucket-acl --bucket my-bucket

# Test with AWS CLI
aws s3 cp test.txt s3://my-bucket/ --debug
```

### Common Causes
- **IAM permissions**: Missing s3:PutObject permission
- **Bucket policy**: Explicit deny or missing allow
- **Encryption**: KMS key permissions missing
- **Public access block**: Bucket settings blocking uploads

### Exact Fix
```bash
# 1. Fix IAM policy
aws iam put-role-policy \
  --role-name MyRole \
  --policy-name S3Access \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }]
  }'

# 2. Update bucket policy
aws s3api put-bucket-policy \
  --bucket my-bucket \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::123456789012:role/MyRole"},
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::my-bucket/*"
    }]
  }'
```

### Terraform Fix
```hcl
resource "aws_iam_role_policy" "s3_access" {
  name = "S3Access"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.app_bucket.arn}/*"
      }
    ]
  })
}
```

## Scenario 3: Lambda cannot reach RDS

### Problem
Lambda function times out when connecting to RDS database.

### Root Cause Analysis
```bash
# Check Lambda VPC configuration
aws lambda get-function-configuration --function-name MyFunction

# Check RDS security groups
aws rds describe-db-instances --db-instance-identifier mydb

# Check subnet groups
aws rds describe-db-subnet-groups --db-subnet-group-name mydb-subnet-group

# Test connectivity
aws lambda invoke \
  --function-name MyFunction \
  --payload '{"test": "connection"}' \
  response.json
```

### Common Causes
- **VPC configuration**: Lambda not in same VPC as RDS
- **Security groups**: RDS security group not allowing Lambda access
- **Subnet routing**: Lambda subnets cannot reach RDS subnets
- **NAT Gateway**: Lambda needs internet access for AWS API calls

### Exact Fix
```bash
# 1. Update Lambda VPC configuration
aws lambda update-function-configuration \
  --function-name MyFunction \
  --vpc-config SubnetIds=subnet-12345,subnet-67890,SecurityGroupIds=sg-lambda

# 2. Update RDS security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 5432 \
  --source-group sg-lambda

# 3. Ensure Lambda has execution role
aws iam attach-role-policy \
  --role-name lambda-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

### Terraform Fix
```hcl
resource "aws_lambda_function" "app" {
  function_name = "MyFunction"
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}
```

## Scenario 4: App loses DB during ASG scale events

### Problem
Application loses database connections when Auto Scaling Group scales in/out.

### Root Cause Analysis
```bash
# Check ASG configuration
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names MyASG

# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Check application logs
aws logs filter-log-events \
  --log-group-name /aws/ec2/myapp \
  --filter-pattern "database connection"

# Check RDS connections
aws rds describe-db-instances --db-instance-identifier mydb
```

### Common Causes
- **Connection pooling**: No connection pool or improper configuration
- **Health checks**: ALB health checks too aggressive
- **Graceful shutdown**: Application not handling SIGTERM properly
- **Database limits**: Max connections exceeded during scale events

### Exact Fix
```bash
# 1. Configure ALB health check
aws elbv2 modify-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 10 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# 2. Update ASG termination policy
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name MyASG \
  --termination-policies "OldestInstance" \
  --default-cooldown 300

# 3. Configure lifecycle hooks
aws autoscaling put-lifecycle-hook \
  --lifecycle-hook-name graceful-shutdown \
  --auto-scaling-group-name MyASG \
  --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING \
  --heartbeat-timeout 300
```

### Application Fix
```javascript
// Connection pooling
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 5432,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pool.end();
  process.exit(0);
});
```

## Scenario 5: CloudWatch not collecting logs

### Problem
Application logs are not appearing in CloudWatch Logs.

### Root Cause Analysis
```bash
# Check CloudWatch agent status
aws ssm get-command-invocation \
  --command-id "command-id" \
  --instance-id i-1234567890abcdef0

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/CloudWatchAgentServerRole \
  --action-names logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents \
  --resource-arns "*"

# Check log groups
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/

# Check agent configuration
cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

### Common Causes
- **Agent not installed**: CloudWatch agent missing or not running
- **IAM permissions**: Missing CloudWatch logs permissions
- **Configuration**: Wrong log file paths or log group names
- **Network**: Agent cannot reach CloudWatch endpoints

### Exact Fix
```bash
# 1. Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm

# 2. Create IAM role
aws iam create-role \
  --role-name CloudWatchAgentServerRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name CloudWatchAgentServerRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# 3. Configure agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard

# 4. Start agent
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
```

### Terraform Fix
```hcl
resource "aws_iam_role" "cloudwatch_agent" {
  name = "CloudWatchAgentServerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent" {
  name = "CloudWatchAgentServerRole"
  role = aws_iam_role.cloudwatch_agent.name
}
```

## General AWS Debugging Commands

### VPC and Networking
```bash
# VPC information
aws ec2 describe-vpcs
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-12345"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-12345"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=vpc-12345"

# Security groups
aws ec2 describe-security-groups --group-ids sg-12345
aws ec2 describe-security-group-rules --group-ids sg-12345

# Network ACLs
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=vpc-12345"
```

### IAM and Permissions
```bash
# Role information
aws iam get-role --role-name MyRole
aws iam list-attached-role-policies --role-name MyRole
aws iam list-role-policies --role-name MyRole

# Policy simulation
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/MyRole \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/my-key
```

### CloudWatch and Monitoring
```bash
# Logs
aws logs describe-log-groups
aws logs describe-log-streams --log-group-name /aws/lambda/my-function
aws logs filter-log-events --log-group-name /aws/lambda/my-function --filter-pattern "ERROR"

# Metrics
aws cloudwatch list-metrics --namespace AWS/EC2
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --statistics Average \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 3600
```
