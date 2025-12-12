# output "argocd_namespace" {
#   description = "ArgoCD namespace"
#   value       = module.argocd.namespace
# }

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile oth_infra"
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = module.eks.karpenter_controller_role_arn
}

output "karpenter_node_role_name" {
  description = "IAM role name for Karpenter nodes"
  value       = module.eks.karpenter_node_role_name
}

output "karpenter_sqs_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = module.eks.karpenter_sqs_queue_name
}

output "grafana_cloudwatch_role_arn" {
  description = "IAM role ARN for Grafana CloudWatch access"
  value       = module.eks.grafana_cloudwatch_role_arn
}

output "ack_eks_controller_role_arn" {
  description = "IAM role ARN for ACK EKS controller"
  value       = module.eks.ack_eks_controller_role_arn
}

# IAM Identity Center (Disabled)
# output "identity_center_setup" {
#   description = "IAM Identity Center setup instructions"
#   value       = module.iam_identity_center.setup_instructions
# }
# 
# output "identity_center_portal_url" {
#   description = "AWS access portal URL"
#   value       = module.iam_identity_center.access_portal_url
# }
# 
# output "identity_center_users" {
#   description = "Users created in Identity Center"
#   value       = module.iam_identity_center.users_created
# }

# RDS Database Outputs
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_secrets_manager_arn" {
  description = "ARN of Secrets Manager secret containing database credentials"
  value       = module.rds.secrets_manager_secret_arn
}

output "rds_connection_info" {
  description = "Database connection information for applications"
  value       = module.rds.connection_info
  sensitive   = true
}
