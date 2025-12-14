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

inputs = {
  aws_region              = "eu-central-1"
  environment             = "dev"
  cluster_name            = "tbyte-dev"
  service_account_name    = "tbyte-app"
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
}
