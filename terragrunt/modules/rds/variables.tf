variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "assume_role_arn" {
  description = "ARN of the role to assume for cross-account access"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of EKS cluster"
  type        = string
  default     = null
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.15"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.postgres_version))
    error_message = "PostgreSQL version must be in format 'major.minor' (e.g., '15.8')."
  }
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "Instance class must start with 'db.' (e.g., 'db.t3.micro')."
  }
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "tbyte"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "postgres"

  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 63
    error_message = "Database username must be between 1 and 63 characters."
  }
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "Max allocated storage must be greater than or equal to allocated storage."
  }
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false # Disabled for cost in test environment
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false # Disabled for easy cleanup in test environment
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = true # Enabled for easy cleanup in test environment
}
