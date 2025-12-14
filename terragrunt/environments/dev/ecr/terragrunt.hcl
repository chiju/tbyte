include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  aws_region    = "eu-central-1"
  environment   = "dev"
  cluster_name  = "tbyte-dev"
}
