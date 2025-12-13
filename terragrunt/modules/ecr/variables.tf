variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "assume_role_arn" {
  description = "Role ARN to assume"
  type        = string
  default     = null
}
