output "backend_service_role_arn" {
  description = "ARN of the backend service IAM role for IRSA"
  value       = aws_iam_role.backend_service_role.arn
}

output "backend_service_role_name" {
  description = "Name of the backend service IAM role"
  value       = aws_iam_role.backend_service_role.name
}

output "eso_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = length(aws_iam_role.eso_role) > 0 ? aws_iam_role.eso_role[0].arn : null
}
