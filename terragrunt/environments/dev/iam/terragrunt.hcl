include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependencies {
  paths = ["../eks", "../rds"]
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_oidc_issuer_url = "https://mock-oidc-issuer"
  }
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:eu-central-1:045129524082:secret:mock-secret"
  }
}

inputs = {
  aws_region              = "eu-central-1"
  environment             = "dev"
  cluster_name            = "tbyte-dev"
  service_account_name    = "tbyte-app"
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
  rds_secret_arn          = dependency.rds.outputs.secret_arn
}
