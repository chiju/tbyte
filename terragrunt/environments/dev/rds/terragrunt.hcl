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

dependencies {
  paths = ["../eks"]
}

inputs = {
  aws_region                       = "eu-central-1"
  environment                      = "dev"
  cluster_name                     = "tbyte-dev"
  vpc_id                          = dependency.vpc.outputs.vpc_id
  vpc_cidr                        = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids              = dependency.vpc.outputs.private_subnet_ids
  # Remove EKS security group dependency - RDS will use its own security group
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  max_allocated_storage           = 40
  postgres_version                = "15.15"
  multi_az                        = false
  backup_retention_period         = 1
  skip_final_snapshot             = true
}
