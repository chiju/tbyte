include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/rds"
}

dependency "bootstrap" {
  config_path = "../../../bootstrap"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "eks" {
  config_path = "../eks"
}

inputs = {
  environment               = "dev"
  assume_role_arn           = dependency.bootstrap.outputs.dev_account_role_arn
  cluster_name              = "tbyte-dev"
  vpc_id                    = dependency.vpc.outputs.vpc_id
  private_subnet_ids        = dependency.vpc.outputs.private_subnet_ids
  eks_cluster_sg_id         = dependency.eks.outputs.cluster_security_group_id
  instance_class            = "db.t3.micro"
  allocated_storage         = 20
  max_allocated_storage     = 40
  engine_version            = "15.8"
  multi_az                  = false
  backup_window             = "03:00-04:00"
  backup_retention_period   = 1
  skip_final_snapshot       = true
}
