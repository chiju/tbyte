include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

inputs = {
  environment        = "production"
  assume_role_arn    = dependency.bootstrap.outputs.production_account_role_arn
  cluster_name       = "tbyte-production"
  cidr               = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}
