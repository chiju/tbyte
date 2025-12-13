# Bootstrap Module: Creates AWS accounts, S3 buckets, and GitHub OIDC

data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}

# Create Organizational Unit
resource "aws_organizations_organizational_unit" "tbyte" {
  name      = "TByte"
  parent_id = data.aws_organizations_organization.current.roots[0].id
}

# S3 buckets for Terragrunt state
resource "aws_s3_bucket" "terragrunt_state" {
  bucket = "tbyte-terragrunt-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "terragrunt_state" {
  bucket = aws_s3_bucket.terragrunt_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terragrunt_state" {
  bucket = aws_s3_bucket.terragrunt_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create AWS accounts in the OU
resource "aws_organizations_account" "dev" {
  name      = "tbyte-dev"
  email     = "aws+dev@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.tbyte.id
}

resource "aws_organizations_account" "staging" {
  name      = "tbyte-staging"
  email     = "aws+staging@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.tbyte.id
}

resource "aws_organizations_account" "production" {
  name      = "tbyte-production"
  email     = "aws+production@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.tbyte.id
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "GitHub-OIDC"
  }
}

# GitHub Actions Role
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsEKSRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Note: Cross-account roles will be created manually or via separate process
# after accounts are created, since we can't assume roles that don't exist yet
