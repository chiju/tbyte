include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "eks" {
  config_path = "../eks"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_name            = "tbyte-dev"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-central-1.amazonaws.com/id/MOCK123456"
  }
}

dependency "rds" {
  config_path = "../rds"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:mock-secret"
  }
}

inputs = {
  aws_region              = "eu-central-1"
  environment             = "dev"
  assume_role_arn         = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name            = dependency.eks.outputs.cluster_name
  service_account_name    = "tbyte-app"
  rds_secret_arn          = dependency.rds.outputs.secret_arn
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
}
