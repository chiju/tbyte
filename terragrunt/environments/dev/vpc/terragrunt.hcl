include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  environment        = "dev"
  cluster_name       = "tbyte-dev"
  cidr               = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
}
