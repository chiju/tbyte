# Multi-Environment Configuration using Terraform Workspaces
# Usage: terraform workspace select dev|staging|production

locals {
  # Current workspace (environment)
  environment = terraform.workspace == "default" ? "dev" : terraform.workspace

  # Environment-specific configurations
  env_configs = {
    dev = {
      cluster_name         = "tbyte-dev"
      instance_type        = "t3.small"
      desired_nodes        = 1
      min_nodes            = 1
      max_nodes            = 3
      db_instance_class    = "db.t3.micro"
      db_allocated_storage = 20
      multi_az             = false
      domain_suffix        = "dev.tbyte.local"
      backup_retention     = 1
      deletion_protection  = false
    }

    staging = {
      cluster_name         = "tbyte-staging"
      instance_type        = "t3.medium"
      desired_nodes        = 2
      min_nodes            = 2
      max_nodes            = 5
      db_instance_class    = "db.t3.small"
      db_allocated_storage = 20
      multi_az             = false
      domain_suffix        = "staging.tbyte.local"
      backup_retention     = 3
      deletion_protection  = false
    }

    production = {
      cluster_name         = "tbyte-production"
      instance_type        = "t3.medium"
      desired_nodes        = 3
      min_nodes            = 2
      max_nodes            = 10
      db_instance_class    = "db.t3.small"
      db_allocated_storage = 50
      multi_az             = true
      domain_suffix        = "tbyte.local"
      backup_retention     = 7
      deletion_protection  = true
    }
  }

  # Get current environment config
  current_env = local.env_configs[local.environment]

  # Common tags with environment
  common_tags = {
    Environment = local.environment
    Project     = "tbyte"
    ManagedBy   = "terraform"
    Workspace   = terraform.workspace
    Assessment  = "devops-engineer"
  }
}
