include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}


dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr          = "10.0.0.0/16"
  }
}

dependency "eks" {
  config_path = "../eks"
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_security_group_id = "sg-mock"
  }
}

inputs = {
  aws_region                       = "eu-central-1"
  environment                      = "staging"
  cluster_name                     = "tbyte-staging"
  vpc_id                          = dependency.vpc.outputs.vpc_id
  vpc_cidr                        = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids              = dependency.vpc.outputs.private_subnet_ids
  eks_cluster_security_group_id   = dependency.eks.outputs.cluster_security_group_id
  instance_class                  = "db.t3.small"
  allocated_storage               = 50
  max_allocated_storage           = 100
  postgres_version                = "15.15"
  multi_az                        = true
  backup_retention_period         = 7
  skip_final_snapshot             = true
}
