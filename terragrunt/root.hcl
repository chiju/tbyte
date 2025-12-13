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

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "tbyte"
      ManagedBy   = "terragrunt"
    }
  }
}

# Data source for EKS cluster authentication token
data "aws_eks_cluster_auth" "cluster" {
  count = try(var.cluster_name, "") != "" ? 1 : 0
  name  = var.cluster_name
}

# Kubernetes Provider - uses exec authentication (evaluated at runtime)
provider "kubernetes" {
  host                   = try(var.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(var.cluster_certificate_authority_data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(var.cluster_name, ""),
      "--region",
      var.aws_region
    ]
  }
}

# Helm Provider - uses token authentication (evaluated at runtime)
provider "helm" {
  kubernetes = {
    host                   = try(var.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(var.cluster_certificate_authority_data), "")
    token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
  }
}
EOF
}

inputs = {
  aws_region = "eu-central-1"
  project    = "tbyte"
}
