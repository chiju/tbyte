# IAM Module

Creates IAM roles and policies for GitHub Actions OIDC authentication.

## Resources Created

- GitHub OIDC Identity Provider
- GitHub Actions IAM role with trust policy
- IAM policies for EKS, ECR, and S3 access
- Cross-account role assumptions (if needed)

## Usage

```hcl
terraform {
  source = "../../../modules/iam"
}

inputs = {
  environment = "dev"
  github_org  = "your-github-org"
  github_repo = "your-repo-name"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment | Environment name | string | - |
| github_org | GitHub organization name | string | - |
| github_repo | GitHub repository name | string | - |
| github_branch | GitHub branch for OIDC | string | "main" |

## Outputs

| Name | Description |
|------|-------------|
| github_actions_role_arn | GitHub Actions IAM role ARN |
| oidc_provider_arn | GitHub OIDC provider ARN |

## GitHub Actions Setup

Add these secrets to your GitHub repository:

```yaml
AWS_ROLE_ARN: <github_actions_role_arn_output>
AWS_REGION: eu-central-1
```

Use in GitHub Actions:
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ secrets.AWS_REGION }}
```
