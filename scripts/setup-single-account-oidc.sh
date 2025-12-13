#!/bin/bash

# Setup OIDC provider and GitHub Actions role in a single account
# Usage: ./setup-single-account-oidc.sh <account-id> <account-name>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <account-id> <account-name>"
    echo "Example: $0 860655786215 staging"
    exit 1
fi

ACCOUNT_ID=$1
ACCOUNT_NAME=$2
REPO="chiju/tbyte"
ROLE_NAME="GitHubActionsEKSRole"

echo "🔧 Setting up OIDC for $ACCOUNT_NAME account ($ACCOUNT_ID)..."

# Assume role to target account
CREDS=$(AWS_PROFILE=oth_infra aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
    --role-session-name "setup-oidc-${ACCOUNT_NAME}" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | cut -d' ' -f1)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | cut -d' ' -f2)
export AWS_SESSION_TOKEN=$(echo $CREDS | cut -d' ' -f3)

# Create OIDC provider
echo "🔐 Creating OIDC provider..."
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    --client-id-list sts.amazonaws.com 2>/dev/null || echo "OIDC provider already exists"

# Create trust policy
cat > /tmp/trust-policy-${ACCOUNT_NAME}.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${REPO}:*"
                }
            }
        }
    ]
}
EOF

# Create role
echo "👤 Creating GitHub Actions role..."
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy-${ACCOUNT_NAME}.json \
    --description "GitHub Actions role for $ACCOUNT_NAME environment" 2>/dev/null || echo "Role already exists"

# Attach policies
echo "📋 Attaching policies..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create S3 state bucket
echo "🪣 Creating S3 state bucket..."
aws s3 mb s3://tbyte-terragrunt-state-${ACCOUNT_ID} --region eu-central-1 2>/dev/null || echo "Bucket already exists"

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket tbyte-terragrunt-state-${ACCOUNT_ID} \
    --versioning-configuration Status=Enabled

echo "✅ $ACCOUNT_NAME account ($ACCOUNT_ID) setup complete!"
echo "   Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/$ROLE_NAME"
echo "   State bucket: s3://tbyte-terragrunt-state-${ACCOUNT_ID}"

# Clean up
rm -f /tmp/trust-policy-${ACCOUNT_NAME}.json
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
