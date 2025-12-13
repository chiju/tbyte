# Bootstrap Module: Creates AWS accounts and cross-account roles

# Create AWS accounts
resource "aws_organizations_account" "dev" {
  name  = "tbyte-dev"
  email = "aws+dev@${var.email_domain}"
}

resource "aws_organizations_account" "staging" {
  name  = "tbyte-staging"
  email = "aws+staging@${var.email_domain}"
}

resource "aws_organizations_account" "production" {
  name  = "tbyte-production"
  email = "aws+production@${var.email_domain}"
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

# Cross-account execution roles
resource "aws_iam_role" "terraform_execution_dev" {
  provider = aws.dev
  name     = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_execution_dev" {
  provider   = aws.dev
  role       = aws_iam_role.terraform_execution_dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role" "terraform_execution_staging" {
  provider = aws.staging
  name     = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_execution_staging" {
  provider   = aws.staging
  role       = aws_iam_role.terraform_execution_staging.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role" "terraform_execution_production" {
  provider = aws.production
  name     = "TerraformExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_execution_production" {
  provider   = aws.production
  role       = aws_iam_role.terraform_execution_production.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_caller_identity" "current" {}
