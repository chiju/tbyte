include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/vpc"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

inputs = {
  environment        = "staging"
  assume_role_arn    = dependency.bootstrap.outputs.staging_account_role_arn
  cluster_name       = "tbyte-staging"
  cidr               = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}
