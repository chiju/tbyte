terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

# S3 bucket for bootstrap state
resource "aws_s3_bucket" "bootstrap_state" {
  bucket = "tbyte-bootstrap-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bootstrap_state" {
  bucket = aws_s3_bucket.bootstrap_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.bootstrap_state.bucket
}
