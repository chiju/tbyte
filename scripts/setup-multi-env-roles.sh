#!/bin/bash
set -e

# Setup environment-specific GitHub Actions roles
GITHUB_REPO="chiju/tbyte"

# Account mappings (from AWS Organizations)
DEV_ACCOUNT="045129524082"      # tbyte-dev
STAGING_ACCOUNT="860655786215"  # tbyte-staging  
PROD_ACCOUNT="136673894425"     # tbyte-production

echo "🚀 Setting up environment-specific GitHub Actions roles..."

# Function to create role in account
create_role() {
    local account_id=$1
    local env_name=$2
    local role_name="TByte${env_name}GitHubActionsRole"
    
    echo "Creating role $role_name in account $account_id ($env_name)..."
    
    # Use organization access for all accounts
    CREDS=$(AWS_PROFILE=oth_infra aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
        --role-session-name "setup-${env_name}-role" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    
    read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< "$CREDS"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    
    # Create OIDC provider if it doesn't exist
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
        2>/dev/null || echo "OIDC provider already exists"

    # Create role
    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Federated\":\"arn:aws:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com\"},\"Action\":\"sts:AssumeRoleWithWebIdentity\",\"Condition\":{\"StringEquals\":{\"token.actions.githubusercontent.com:aud\":\"sts.amazonaws.com\"},\"StringLike\":{\"token.actions.githubusercontent.com:sub\":\"repo:${GITHUB_REPO}:*\"}}}]}" \
        --description "GitHub Actions role for TByte ${env_name} environment" \
        2>/dev/null || echo "Role already exists"
    
    # Attach AdministratorAccess policy
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    
    echo "✅ Role created: arn:aws:iam::${account_id}:role/${role_name}"
    
    # Clean up credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

# Create roles in each environment
create_role "$DEV_ACCOUNT" "Dev"
create_role "$STAGING_ACCOUNT" "Staging"  
create_role "$PROD_ACCOUNT" "Prod"

echo ""
echo "🎉 All environment-specific roles created!"
echo ""
echo "📋 GitHub Secrets should be set to:"
echo "AWS_ROLE_ARN_DEV: arn:aws:iam::${DEV_ACCOUNT}:role/TByteDevGitHubActionsRole"
echo "AWS_ROLE_ARN_STAGING: arn:aws:iam::${STAGING_ACCOUNT}:role/TByteStagingGitHubActionsRole"
echo "AWS_ROLE_ARN_PRODUCTION: arn:aws:iam::${PROD_ACCOUNT}:role/TByteProdGitHubActionsRole"
