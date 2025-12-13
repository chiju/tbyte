include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
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
  # Remove assume_role_arn for single account setup
  # assume_role_arn         = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name            = "tbyte-dev"
  kubernetes_version      = "1.34"
  # Use the GitHub Actions role from the same account
  github_actions_role_arn = "arn:aws:iam::432801802107:role/GitHubActionsEKSRole"
  public_subnet_ids       = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  node_instance_type      = "t3.small"
  desired_nodes           = 1
  min_nodes               = 1
  max_nodes               = 3
}
