#!/bin/bash

# Setup OIDC provider and GitHub Actions role in all accounts
# Based on GitLab multi-account pattern

set -e

REPO="chiju/tbyte"
ROLE_NAME="GitHubActionsEKSRole"

setup_account_oidc() {
    local env=$1
    local account_id=$2
    
    echo "🔧 Setting up OIDC for $env account ($account_id)..."
    
    # Assume role to target account (skip for dev account as we already have direct access)
    if [ "$account_id" != "045129524082" ]; then
        echo "📋 Assuming role to $env account..."
        CREDS=$(AWS_PROFILE=oth_infra aws sts assume-role \
            --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
            --role-session-name "setup-oidc-${env}" \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text)
        
        export AWS_ACCESS_KEY_ID=$(echo $CREDS | cut -d' ' -f1)
        export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | cut -d' ' -f2)
        export AWS_SESSION_TOKEN=$(echo $CREDS | cut -d' ' -f3)
    fi
    
    # Create OIDC provider (if not exists)
    echo "🔐 Creating OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        --client-id-list sts.amazonaws.com 2>/dev/null || echo "OIDC provider already exists"
    
    # Create trust policy
    cat > /tmp/trust-policy-${env}.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com"
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
        --assume-role-policy-document file:///tmp/trust-policy-${env}.json \
        --description "GitHub Actions role for $env environment" 2>/dev/null || echo "Role already exists"
    
    # Attach policies
    echo "📋 Attaching policies..."
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    
    # Create S3 state bucket
    echo "🪣 Creating S3 state bucket..."
    aws s3 mb s3://tbyte-terragrunt-state-${account_id} --region eu-central-1 2>/dev/null || echo "Bucket already exists"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket tbyte-terragrunt-state-${account_id} \
        --versioning-configuration Status=Enabled
    
    echo "✅ $env account setup complete!"
    
    # Clean up temp files
    rm -f /tmp/trust-policy-${env}.json
    
    # Reset AWS credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

# Setup all accounts with actual IDs
setup_account_oidc "dev" "045129524082"
setup_account_oidc "staging" "860655786215" 
setup_account_oidc "production" "136673894425"

echo ""
echo "🎉 Multi-account OIDC setup complete!"
echo ""
echo "📋 Account roles created:"
echo "  dev: arn:aws:iam::045129524082:role/$ROLE_NAME"
echo "  staging: arn:aws:iam::860655786215:role/$ROLE_NAME"  
echo "  production: arn:aws:iam::136673894425:role/$ROLE_NAME"
