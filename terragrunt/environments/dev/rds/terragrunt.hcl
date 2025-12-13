include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "vpc" {
  config_path = "../vpc"
  skip_outputs = true
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
    vpc_cidr          = "10.0.0.0/16"
  }
}

dependency "eks" {
  config_path = "../eks"
  skip_outputs = true
  
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    cluster_security_group_id = "sg-mock"
  }
}

inputs = {
  aws_region                       = "eu-central-1"
  environment                      = "dev"
  assume_role_arn                  = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name                     = "tbyte-dev"
  vpc_id                          = dependency.vpc.outputs.vpc_id
  vpc_cidr                        = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids              = dependency.vpc.outputs.private_subnet_ids
  eks_cluster_security_group_id   = dependency.eks.outputs.cluster_security_group_id
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  max_allocated_storage           = 40
  postgres_version                = "15.8"
  multi_az                        = false
  backup_retention_period         = 1
  skip_final_snapshot             = true
}
