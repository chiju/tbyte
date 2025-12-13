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
  environment               = "staging"
  assume_role_arn           = dependency.bootstrap.outputs.staging_account_role_arn
  cluster_name              = "tbyte-staging"
  vpc_id                    = dependency.vpc.outputs.vpc_id
  private_subnet_ids        = dependency.vpc.outputs.private_subnet_ids
  eks_cluster_sg_id         = dependency.eks.outputs.cluster_security_group_id
  instance_class            = "db.t3.small"
  allocated_storage         = 50
  max_allocated_storage     = 100
  engine_version            = "15.8"
  multi_az                  = true
  backup_window             = "03:00-04:00"
  backup_retention_period   = 7
  skip_final_snapshot       = true
}
