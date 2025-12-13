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
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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

# Kubernetes Provider - only configured when cluster variables are available
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

# Helm Provider - only configured when cluster variables are available
provider "helm" {
  kubernetes = {
    host                   = try(var.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(var.cluster_certificate_authority_data), "")
    exec = {
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
}
EOF
}

inputs = {
  aws_region = "eu-central-1"
  project    = "tbyte"
}
