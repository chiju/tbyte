# Bootstrap: Creates AWS accounts, GitHub OIDC
# Uses dedicated S3 bucket created separately

remote_state {
  backend = "s3"
  config = {
    encrypt      = true
    bucket       = "tbyte-bootstrap-state-432801802107"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  
  default_tags {
    tags = {
      Environment = "bootstrap"
      Project     = "tbyte"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

terraform {
  source = "../modules/bootstrap"
}

inputs = {
  aws_region      = "eu-central-1"
  environment     = "bootstrap"
  github_repo     = "chiju/tbyte"
  email_domain    = "example.com"
}
