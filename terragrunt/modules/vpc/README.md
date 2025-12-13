# VPC Module

Creates a production-ready VPC with public/private subnets, NAT gateway, and flow logs.

## Resources Created

- VPC with custom CIDR
- Public subnets (2 AZs) with Internet Gateway
- Private subnets (2 AZs) with NAT Gateway
- Route tables and associations
- VPC Flow Logs to CloudWatch
- Default security group (locked down)

## Usage

```hcl
terraform {
  source = "../../../modules/vpc"
}

inputs = {
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  project     = "tbyte"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | - |
| vpc_cidr | VPC CIDR block | string | "10.0.0.0/16" |
| project | Project name for tagging | string | "tbyte" |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| internet_gateway_id | Internet Gateway ID |
| nat_gateway_id | NAT Gateway ID |
