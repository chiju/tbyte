#!/bin/bash
set -e

# Setup OIDC provider and GitHub Actions role in dev account (045129524082)

ROLE_NAME="GitHubActionsEKSRole"
GITHUB_REPO="chiju/tbyte"
DEV_ACCOUNT_ID="045129524082"

echo "🚀 Setting up OIDC in dev account: $DEV_ACCOUNT_ID"

# Assume dev account role first
echo "Assuming dev account role..."
CREDS=$(AWS_PROFILE=oth_infra aws sts assume-role \
  --role-arn "arn:aws:iam::${DEV_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "setup-oidc" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< "$CREDS"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

echo "✅ Assumed dev account role"

# Check if OIDC provider exists
OIDC_PROVIDER_ARN="arn:aws:iam::${DEV_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN 2>/dev/null; then
  echo "✅ OIDC provider already exists"
else
  echo "Creating OIDC provider in dev account..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
  echo "✅ OIDC provider created"
fi

# Create trust policy
cat > /tmp/dev-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role in dev account
echo "Creating IAM role in dev account: $ROLE_NAME..."
if aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
  echo "⚠️  Role already exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document file:///tmp/dev-trust-policy.json
else
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/dev-trust-policy.json \
    --description "GitHub Actions role for EKS GitOps in dev account"
  echo "✅ Role created in dev account"
fi

# Attach policies
echo "Attaching policies..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

DEV_ROLE_ARN="arn:aws:iam::${DEV_ACCOUNT_ID}:role/${ROLE_NAME}"

echo ""
echo "✅ Dev account OIDC setup complete!"
echo "Dev Role ARN: $DEV_ROLE_ARN"
echo ""
echo "🔧 Now add this role to EKS access entries..."
echo "aws eks create-access-entry --cluster-name tbyte-dev --principal-arn $DEV_ROLE_ARN --region eu-central-1"
echo "aws eks associate-access-policy --cluster-name tbyte-dev --principal-arn $DEV_ROLE_ARN --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region eu-central-1"
