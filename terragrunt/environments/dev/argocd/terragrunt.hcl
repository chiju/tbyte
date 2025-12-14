include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/argocd"
}

dependencies {
  paths = ["../eks"]
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name                        = "mock-cluster"
    cluster_endpoint                    = "https://mock-endpoint"
    cluster_certificate_authority_data  = "mock-cert"
  }
}

inputs = {
  aws_region      = "eu-central-1"
  environment     = "dev"
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  
  # ArgoCD configuration - use GitHub secrets
  git_repo_url                = "https://github.com/chiju/tbyte.git"
  git_target_revision         = "main"
  git_apps_path              = "argocd-apps"
  github_app_id              = get_env("TF_VAR_github_app_id", "")
  github_app_installation_id = get_env("TF_VAR_github_app_installation_id", "")
  github_app_private_key     = get_env("TF_VAR_github_app_private_key", "")
}
