# S3 backend with native state locking (no DynamoDB needed)
# For GitHub Actions with OIDC - no profile needed
terraform {
  backend "s3" {
    bucket       = "tbyte-tfstate-8fde7107"
    key          = "tbyte.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
