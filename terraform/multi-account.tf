# Multi-Account Environment Setup
# This creates separate AWS accounts for each environment

locals {
  # Account configuration
  accounts = {
    shared-services = "432801802107" # Your root account (oth_infra)
    dev             = var.dev_account_id
    staging         = var.staging_account_id
    production      = var.production_account_id
  }

  # Current account being deployed to
  current_account = local.accounts[var.target_environment]

  # Environment-specific configurations
  env_configs = {
    dev = {
      cluster_name      = "tbyte-dev"
      instance_type     = "t3.small"
      desired_nodes     = 1
      min_nodes         = 1
      max_nodes         = 3
      db_instance_class = "db.t3.micro"
      account_id        = var.dev_account_id
      assume_role_arn   = "arn:aws:iam::${var.dev_account_id}:role/TerraformExecutionRole"
    }

    staging = {
      cluster_name      = "tbyte-staging"
      instance_type     = "t3.medium"
      desired_nodes     = 2
      min_nodes         = 2
      max_nodes         = 5
      db_instance_class = "db.t3.small"
      account_id        = var.staging_account_id
      assume_role_arn   = "arn:aws:iam::${var.staging_account_id}:role/TerraformExecutionRole"
    }

    production = {
      cluster_name      = "tbyte-production"
      instance_type     = "t3.medium"
      desired_nodes     = 3
      min_nodes         = 2
      max_nodes         = 10
      db_instance_class = "db.t3.small"
      account_id        = var.production_account_id
      assume_role_arn   = "arn:aws:iam::${var.production_account_id}:role/TerraformExecutionRole"
    }
  }

  # Get current environment config
  current_env = local.env_configs[var.target_environment]
}

# Provider for target account
provider "aws" {
  alias  = "target"
  region = var.region

  assume_role {
    role_arn = local.current_env.assume_role_arn
  }

  default_tags {
    tags = {
      Environment = var.target_environment
      Project     = "tbyte"
      ManagedBy   = "terraform"
      Account     = local.current_env.account_id
    }
  }
}

# Provider for shared services (ECR)
provider "aws" {
  alias  = "shared"
  region = var.region
  # Uses default profile (oth_infra)
}

# Account validation for target account
data "aws_caller_identity" "target" {
  provider = aws.target
}

resource "null_resource" "target_account_validation" {
  count = data.aws_caller_identity.target.account_id != local.current_env.account_id ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: Deploying to wrong account ${data.aws_caller_identity.target.account_id}, expected ${local.current_env.account_id}' && exit 1"
  }
}
