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
  environment             = "production"
  cluster_name            = "tbyte-production"
  kubernetes_version      = "1.34"
  github_actions_role_arn = get_env("GITHUB_ACTIONS_ROLE_ARN", "")
  public_subnet_ids       = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  node_instance_type      = "t3.medium"
  desired_nodes           = 3
  min_nodes               = 2
  max_nodes               = 10
}
