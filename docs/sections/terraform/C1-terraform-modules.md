# C1 — Create Terraform for AWS

## Problem
Create comprehensive Terraform modules for AWS infrastructure:
- VPC, EKS, node groups, IAM, RDS modules
- Variables with validation
- Outputs for module composition
- Remote state configuration
- README with usage instructions and example workspaces

## Approach
**Modular Terraform Architecture with Terragrunt:**
- **Terragrunt**: DRY configuration and remote state management
- **Modular Design**: Reusable modules for different environments
- **Variable Validation**: Input validation and type constraints
- **Output Composition**: Modules that work together seamlessly
- **Documentation**: Clear usage examples and best practices

## Solution

### Directory Structure
```
terragrunt/
├── terragrunt.hcl                 # Root configuration
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── eks/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── nodegroups/
│   ├── iam/
│   └── rds/
└── environments/
    ├── dev/
    │   ├── terragrunt.hcl
    │   ├── vpc/
    │   ├── eks/
    │   └── rds/
    └── prod/
```

### VPC Module
```hcl
# modules/vpc/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets must be specified."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets must be specified."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/vpc/main.tf
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public"
    "kubernetes.io/role/elb" = "1"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  domain = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-eip-${count.index + 1}"
  })
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-gateway-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-rt"
  })
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-rt-${count.index + 1}"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}
```

### EKS Module
```hcl
# modules/eks/variables.tf
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets must be specified for high availability."
  }
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  validation {
    condition = alltrue([
      for log_type in var.cluster_log_types : contains([
        "api", "audit", "authenticator", "controllerManager", "scheduler"
      ], log_type)
    ])
    error_message = "Invalid log type. Valid types are: api, audit, authenticator, controllerManager, scheduler."
  }
}
```

### IAM Module
```hcl
# modules/iam/main.tf
# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group" {
  name = "${var.cluster_name}-node-group-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}
```

### Remote State Configuration
```hcl
# terragrunt.hcl (root)
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "tbyte-terraform-state-${get_aws_account_id()}"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "eu-central-1"
    
    dynamodb_table = "tbyte-terraform-locks"
    encrypt        = true
    
    s3_bucket_tags = {
      Owner       = "terragrunt"
      Environment = "shared"
    }
    
    dynamodb_table_tags = {
      Owner       = "terragrunt"
      Environment = "shared"
    }
  }
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = "${local.environment}"
      Project     = "tbyte"
    }
  }
}
EOF
}

locals {
  environment = basename(dirname(get_terragrunt_dir()))
}
```

### Environment Configuration
```hcl
# environments/dev/vpc/terragrunt.hcl
terraform {
  source = "../../../modules//vpc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  
  availability_zones = [
    "eu-central-1a",
    "eu-central-1b"
  ]
  
  public_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
  
  private_subnet_cidrs = [
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]
  
  tags = {
    Project = "tbyte"
    Owner   = "devops-team"
  }
}
```

## Result

### Module Benefits
- ✅ **Reusability**: Modules used across dev, staging, prod environments
- ✅ **Validation**: Input validation prevents configuration errors
- ✅ **Composition**: Modules work together through well-defined outputs
- ✅ **State Management**: Remote state with locking prevents conflicts
- ✅ **Documentation**: Clear README files with usage examples

### Terragrunt Advantages
- **DRY Configuration**: Shared configuration across environments
- **Remote State**: Automatic S3 backend configuration
- **Dependency Management**: Automatic dependency resolution
- **Environment Isolation**: Separate state files per environment

### Usage Examples
```bash
# Deploy entire environment
cd environments/dev
terragrunt run-all apply

# Deploy specific module
cd environments/dev/vpc
terragrunt apply

# Plan changes across all modules
terragrunt run-all plan
```
