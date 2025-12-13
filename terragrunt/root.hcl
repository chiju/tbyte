# Root Terragrunt Configuration
remote_state {
  backend = "s3"
  config = {
    encrypt      = true
    bucket       = "tbyte-terragrunt-state-${get_aws_account_id()}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "tbyte"
      ManagedBy   = "terragrunt"
    }
  }
}

# Data source to get EKS cluster info (only when cluster exists)
data "aws_eks_cluster" "cluster" {
  count = var.cluster_name != null && var.cluster_name != "" ? 1 : 0
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.cluster_name != null && var.cluster_name != "" ? 1 : 0
  name  = var.cluster_name
}

# Kubernetes Provider - only configured when cluster exists
provider "kubernetes" {
  host                   = var.cluster_name != null && var.cluster_name != "" ? data.aws_eks_cluster.cluster[0].endpoint : ""
  cluster_ca_certificate = var.cluster_name != null && var.cluster_name != "" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data) : ""
  token                  = var.cluster_name != null && var.cluster_name != "" ? data.aws_eks_cluster_auth.cluster[0].token : ""
}

# Helm Provider - only configured when cluster exists  
provider "helm" {
  kubernetes = {
    host                   = var.cluster_name != null && var.cluster_name != "" ? data.aws_eks_cluster.cluster[0].endpoint : ""
    cluster_ca_certificate = var.cluster_name != null && var.cluster_name != "" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data) : ""
    token                  = var.cluster_name != null && var.cluster_name != "" ? data.aws_eks_cluster_auth.cluster[0].token : ""
  }
}
EOF
}

inputs = {
  aws_region = "eu-central-1"
  project    = "tbyte"
}
