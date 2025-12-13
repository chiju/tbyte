# IAM Module - Centralized IAM resources for EKS cluster
# Best practice: All IAM resources in one module for consistency

# Data sources - conditional to allow planning without existing cluster
data "aws_eks_cluster" "cluster" {
  count = can(regex("MOCK", var.cluster_oidc_issuer_url)) ? 0 : 1
  name  = var.cluster_name
}

data "aws_caller_identity" "current" {}

locals {
  oidc_issuer_url = can(regex("MOCK", var.cluster_oidc_issuer_url)) ? 
    replace(var.cluster_oidc_issuer_url, "https://", "") : 
    replace(data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer, "https://", "")
}

# IRSA Role for Backend Service
resource "aws_iam_role" "backend_service_role" {
  name = "${var.cluster_name}-backend-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_url}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-backend-service-role"
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "irsa"
  }
}

# Policy for RDS access
resource "aws_iam_policy" "backend_rds_policy" {
  name        = "${var.cluster_name}-backend-rds-policy"
  description = "Allows backend service to access RDS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-backend-rds-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Policy for Secrets Manager access
resource "aws_iam_policy" "backend_secrets_policy" {
  name        = "${var.cluster_name}-backend-secrets-policy"
  description = "Allows backend service to access RDS secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.rds_secret_arn
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-backend-secrets-policy"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "backend_rds_policy" {
  role       = aws_iam_role.backend_service_role.name
  policy_arn = aws_iam_policy.backend_rds_policy.arn
}

resource "aws_iam_role_policy_attachment" "backend_secrets_policy" {
  role       = aws_iam_role.backend_service_role.name
  policy_arn = aws_iam_policy.backend_secrets_policy.arn
}
