include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../modules/ecr"
}

inputs = {
  cluster_name    = "tbyte"
  environment     = "shared"
}
