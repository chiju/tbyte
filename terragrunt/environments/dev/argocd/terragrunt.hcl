include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/argocd"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "iam" {
  config_path = "../iam"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    github_actions_role_arn = "arn:aws:iam::123456789012:role/mock-role"
  }
}

dependency "eks" {
  config_path = "../eks"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_name     = "tbyte-dev"
    cluster_endpoint = "https://mock-endpoint"
    cluster_certificate_authority_data = "mock-ca-data"
  }
}

inputs = {
  aws_region      = "eu-central-1"
  environment     = "dev"
  assume_role_arn = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
}
