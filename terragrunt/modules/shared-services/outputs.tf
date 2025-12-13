output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = module.ecr.frontend_repository_url
}

output "backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = module.ecr.backend_repository_url
}

output "frontend_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = module.ecr.frontend_repository_name
}

output "backend_repository_name" {
  description = "Name of the backend ECR repository"
  value       = module.ecr.backend_repository_name
}
