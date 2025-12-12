# RDS PostgreSQL Module

Production-ready RDS PostgreSQL module for microservices architecture.

## Features

- **Security**: Encrypted storage, VPC isolation, security groups
- **High Availability**: Multi-AZ support (configurable)
- **Monitoring**: Enhanced monitoring, Performance Insights
- **Backup**: Automated backups with configurable retention
- **Secrets**: AWS Secrets Manager integration
- **Validation**: Input validation for all variables

## Usage

```hcl
module "rds" {
  source = "./modules/rds"

  cluster_name               = "tbyte"
  environment               = "dev"
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = module.vpc.vpc_cidr
  private_subnet_ids        = module.vpc.private_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id

  # Database configuration
  postgres_version = "15.8"
  instance_class   = "db.t3.micro"
  db_name         = "tbyte"
  db_username     = "postgres"

  # Storage configuration
  allocated_storage     = 20
  max_allocated_storage = 100

  # High availability (disabled for cost in test)
  multi_az = false

  # Backup configuration
  backup_retention_period = 7

  # Security (configured for easy cleanup in test)
  deletion_protection  = false
  skip_final_snapshot = true
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| vpc_id | VPC ID where RDS will be deployed | `string` | n/a | yes |
| private_subnet_ids | List of private subnet IDs for RDS | `list(string)` | n/a | yes |
| eks_node_security_group_id | Security group ID of EKS nodes | `string` | n/a | yes |
| postgres_version | PostgreSQL version | `string` | `"15.8"` | no |
| instance_class | RDS instance class | `string` | `"db.t3.micro"` | no |
| multi_az | Enable Multi-AZ deployment | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| db_endpoint | RDS instance endpoint |
| db_port | RDS instance port |
| db_name | Database name |
| secrets_manager_secret_arn | ARN of the Secrets Manager secret |
| connection_info | Database connection information for applications |

## Security

- Database is deployed in private subnets only
- Security group restricts access to EKS nodes and VPC CIDR
- Passwords stored in AWS Secrets Manager
- Storage encryption enabled
- Enhanced monitoring enabled

## Cost Optimization

For test environments:
- Uses `db.t3.micro` (cheapest option)
- Multi-AZ disabled (reduces cost by 50%)
- Deletion protection disabled for easy cleanup
- Skip final snapshot for faster deletion

For production:
- Enable Multi-AZ: `multi_az = true`
- Use larger instance: `instance_class = "db.t3.small"`
- Enable deletion protection: `deletion_protection = true`
- Create final snapshot: `skip_final_snapshot = false`

## Monitoring

- Enhanced monitoring with 60-second granularity
- Performance Insights enabled (7-day retention)
- CloudWatch integration for metrics and alarms

## Backup Strategy

- Automated daily backups during maintenance window
- 7-day retention period (configurable)
- Point-in-time recovery enabled
- Maintenance window: Sunday 04:00-05:00 UTC

## Production Upgrade Path

For production workloads, consider upgrading to:
- **Aurora PostgreSQL**: Better performance, serverless options
- **Aurora Serverless v2**: Auto-scaling compute
- **Multi-region**: Cross-region read replicas
- **Advanced monitoring**: Custom CloudWatch dashboards
