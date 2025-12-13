variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "assume_role_arn" {
  description = "Role ARN to assume"
  type        = string
  default     = null
}
