# Bootstrap Module

Creates foundational infrastructure for multi-account Terragrunt setup including S3 backend and cross-account IAM roles.

## Resources Created

- S3 bucket for Terraform state with versioning and encryption
- Cross-account IAM roles for dev/staging/production environments
- IAM policies for Terragrunt operations
- S3 bucket policy for secure state access

## Usage

```hcl
terraform {
  source = "../modules/bootstrap"
}

inputs = {
  project_name = "tbyte"
  environments = ["dev", "staging", "production"]
  
  # Account IDs for cross-account access
  dev_account_id        = "123456789012"
  staging_account_id    = "123456789013" 
  production_account_id = "123456789014"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| project_name | Project name for resource naming | string | "tbyte" |
| environments | List of environments | list(string) | ["dev", "staging", "production"] |
| dev_account_id | AWS account ID for dev | string | - |
| staging_account_id | AWS account ID for staging | string | - |
| production_account_id | AWS account ID for production | string | - |
| s3_bucket_name | S3 bucket name for state | string | auto-generated |

## Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | S3 bucket name for Terraform state |
| s3_bucket_arn | S3 bucket ARN |
| dev_account_role_arn | IAM role ARN for dev account |
| staging_account_role_arn | IAM role ARN for staging account |
| production_account_role_arn | IAM role ARN for production account |

## Deployment

This module must be deployed first:

```bash
cd terragrunt/bootstrap
terragrunt apply
```

After deployment, update `root.hcl` with the S3 bucket name from outputs.
