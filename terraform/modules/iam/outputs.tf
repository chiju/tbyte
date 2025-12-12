output "backend_service_role_arn" {
  description = "ARN of the backend service IAM role for IRSA"
  value       = aws_iam_role.backend_service_role.arn
}

output "backend_service_role_name" {
  description = "Name of the backend service IAM role"
  value       = aws_iam_role.backend_service_role.name
}
