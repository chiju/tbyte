include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/argocd"
}

dependencies {
  paths = ["../eks"]
}

inputs = {
  aws_region      = "eu-central-1"
  environment     = "dev"
  cluster_name    = "tbyte-dev"
  # ArgoCD will get cluster info from kubeconfig after EKS is created
  
  # ArgoCD configuration - use GitHub secrets
  git_repo_url                = "https://github.com/chiju/tbyte.git"
  git_target_revision         = "main"
  git_apps_path              = "argocd-apps"
  github_app_id              = get_env("TF_VAR_github_app_id", "")
  github_app_installation_id = get_env("TF_VAR_github_app_installation_id", "")
  github_app_private_key     = get_env("TF_VAR_github_app_private_key", "")
}
