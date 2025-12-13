# Shared Services: ECR repositories, shared resources
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../modules/shared-services"
}

inputs = {
  environment     = "shared-services"
  assume_role_arn = null  # Uses root account credentials
}
