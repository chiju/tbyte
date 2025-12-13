# External Secrets Operator IAM Role - conditional creation
resource "aws_iam_role" "eso_role" {
  count = var.cluster_oidc_issuer_url != null ? 1 : 0
  name  = "${var.cluster_name}-eso-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_url}"
        }
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-eso-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "eso_secrets_policy" {
  count = var.cluster_oidc_issuer_url != null ? 1 : 0
  name  = "${var.cluster_name}-eso-secrets-policy"
  role  = aws_iam_role.eso_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.rds_secret_arn
      }
    ]
  })
}
