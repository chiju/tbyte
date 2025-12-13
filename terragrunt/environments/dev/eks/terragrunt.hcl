include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
    public_subnet_ids  = ["subnet-mock-3", "subnet-mock-4"]
  }
}

inputs = {
  environment             = "dev"
  assume_role_arn         = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name            = "tbyte-dev"
  kubernetes_version      = "1.34"
  github_actions_role_arn = dependency.bootstrap.outputs.github_actions_role_arn
  public_subnet_ids       = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  node_instance_type      = "t3.small"
  desired_nodes           = 1
  min_nodes               = 1
  max_nodes               = 3
}
