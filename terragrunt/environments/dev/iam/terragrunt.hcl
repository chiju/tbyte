include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

inputs = {
  aws_region      = "eu-central-1"
  environment     = "dev"
  assume_role_arn = dependency.bootstrap.outputs.dev_account_role_arn
}
