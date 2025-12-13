output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.postgres.arn
}

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_username" {
  description = "Database username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "db_security_group_id" {
  description = "Security group ID for RDS instance"
  value       = aws_security_group.postgres.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.postgres.name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.postgres_password.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.postgres_password.name
}

# Connection string for applications (without password for security)
output "connection_info" {
  description = "Database connection information for applications"
  value = {
    host       = aws_db_instance.postgres.endpoint
    port       = aws_db_instance.postgres.port
    database   = aws_db_instance.postgres.db_name
    username   = aws_db_instance.postgres.username
    secret_arn = aws_secretsmanager_secret.postgres_password.arn
  }
}
output "secret_arn" {
  description = "ARN of the RDS password secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.postgres_password.arn
}
