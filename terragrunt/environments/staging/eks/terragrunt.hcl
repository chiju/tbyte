include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/eks"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  environment             = "staging"
  assume_role_arn         = dependency.bootstrap.outputs.staging_account_role_arn
  cluster_name            = "tbyte-staging"
  kubernetes_version      = "1.34"
  github_actions_role_arn = dependency.bootstrap.outputs.github_actions_role_arn
  public_subnet_ids       = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  node_instance_type      = "t3.medium"
  desired_nodes           = 2
  min_nodes               = 2
  max_nodes               = 5
}
