include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/iam"
}

dependencies {
  paths = ["../eks", "../rds"]
}

inputs = {
  aws_region              = "eu-central-1"
  environment             = "dev"
  cluster_name            = "tbyte-dev"
  service_account_name    = "tbyte-app"
  # IAM will get OIDC issuer URL from EKS data source after cluster is created
  # RDS secret ARN will be looked up by name after RDS is created
}
