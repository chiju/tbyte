# Bootstrap: Creates AWS accounts, S3 backend, IAM roles
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../modules/bootstrap"
}

inputs = {
  environment     = "bootstrap"
  assume_role_arn = null  # Uses root account credentials
  
  # GitHub OIDC
  github_repo = "chiju/tbyte"
}
