variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "assume_role_arn" {
  description = "Role ARN to assume (null for root account)"
  type        = string
  default     = null
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "email_domain" {
  description = "Email domain for AWS accounts"
  type        = string
  default     = "example.com"
}
