# RDS Module

Creates a PostgreSQL RDS instance with security groups and subnet groups.

## Resources Created

- RDS PostgreSQL instance
- DB subnet group (private subnets)
- Security group allowing access from EKS cluster
- Random password for database
- Parameter group for PostgreSQL optimization

## Usage

```hcl
terraform {
  source = "../../../modules/rds"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "eks" {
  config_path = "../eks"
}

inputs = {
  environment                   = "dev"
  cluster_name                  = "tbyte-dev"
  vpc_id                       = dependency.vpc.outputs.vpc_id
  vpc_cidr                     = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids           = dependency.vpc.outputs.private_subnet_ids
  eks_cluster_security_group_id = dependency.eks.outputs.cluster_security_group_id
  instance_class               = "db.t3.micro"
  allocated_storage            = 20
  postgres_version             = "15.15"
  multi_az                     = false
  backup_retention_period      = 7
  skip_final_snapshot          = true
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | - |
| cluster_name | EKS cluster name | string | - |
| vpc_id | VPC ID | string | - |
| vpc_cidr | VPC CIDR block | string | - |
| private_subnet_ids | Private subnet IDs | list(string) | - |
| eks_cluster_security_group_id | EKS cluster security group ID | string | - |
| instance_class | RDS instance class | string | "db.t3.micro" |
| allocated_storage | Initial storage in GB | number | 20 |
| postgres_version | PostgreSQL version | string | "15.15" |
| multi_az | Enable Multi-AZ | bool | false |
| backup_retention_period | Backup retention days | number | 7 |
| skip_final_snapshot | Skip final snapshot | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| db_instance_id | RDS instance ID |
| db_instance_endpoint | RDS instance endpoint |
| db_instance_port | RDS instance port |
| db_name | Database name |
| db_username | Database username |
