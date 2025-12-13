#!/bin/bash
set -e

echo "🏗️ Multi-Account Terraform Setup"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ROOT_PROFILE="oth_infra"
ROOT_ACCOUNT_ID="432801802107"

# Account IDs (will be prompted)
DEV_ACCOUNT_ID=""
STAGING_ACCOUNT_ID=""
PRODUCTION_ACCOUNT_ID=""

create_aws_accounts() {
    echo -e "${YELLOW}Creating AWS accounts via Organizations...${NC}"
    
    export AWS_PROFILE=$ROOT_PROFILE
    
    # Create DEV account
    echo "Creating DEV account..."
    DEV_RESULT=$(aws organizations create-account \
        --email "chiju2025y1+dev@yahoo.com" \
        --account-name "TByte-DEV" \
        --role-name "OrganizationAccountAccessRole" \
        --output json)
    
    DEV_REQUEST_ID=$(echo $DEV_RESULT | jq -r '.CreateAccountStatus.Id')
    
    # Create STAGING account
    echo "Creating STAGING account..."
    STAGING_RESULT=$(aws organizations create-account \
        --email "chiju2025y1+staging@yahoo.com" \
        --account-name "TByte-STAGING" \
        --role-name "OrganizationAccountAccessRole" \
        --output json)
    
    STAGING_REQUEST_ID=$(echo $STAGING_RESULT | jq -r '.CreateAccountStatus.Id')
    
    # Create PRODUCTION account
    echo "Creating PRODUCTION account..."
    PRODUCTION_RESULT=$(aws organizations create-account \
        --email "chiju2025y1+production@yahoo.com" \
        --account-name "TByte-PRODUCTION" \
        --role-name "OrganizationAccountAccessRole" \
        --output json)
    
    PRODUCTION_REQUEST_ID=$(echo $PRODUCTION_RESULT | jq -r '.CreateAccountStatus.Id')
    
    # Wait for accounts to be created
    echo "Waiting for accounts to be created..."
    sleep 30
    
    # Get account IDs
    DEV_ACCOUNT_ID=$(aws organizations describe-create-account-status \
        --create-account-request-id $DEV_REQUEST_ID \
        --query 'CreateAccountStatus.AccountId' --output text)
    
    STAGING_ACCOUNT_ID=$(aws organizations describe-create-account-status \
        --create-account-request-id $STAGING_REQUEST_ID \
        --query 'CreateAccountStatus.AccountId' --output text)
    
    PRODUCTION_ACCOUNT_ID=$(aws organizations describe-create-account-status \
        --create-account-request-id $PRODUCTION_REQUEST_ID \
        --query 'CreateAccountStatus.AccountId' --output text)
    
    echo -e "${GREEN}✅ Accounts created:${NC}"
    echo "DEV: $DEV_ACCOUNT_ID"
    echo "STAGING: $STAGING_ACCOUNT_ID"
    echo "PRODUCTION: $PRODUCTION_ACCOUNT_ID"
}

setup_cross_account_roles() {
    echo -e "${YELLOW}Setting up cross-account roles...${NC}"
    
    for env in dev staging production; do
        local account_id=""
        case $env in
            dev) account_id=$DEV_ACCOUNT_ID ;;
            staging) account_id=$STAGING_ACCOUNT_ID ;;
            production) account_id=$PRODUCTION_ACCOUNT_ID ;;
        esac
        
        echo "Setting up role in $env account ($account_id)..."
        
        # Assume OrganizationAccountAccessRole to create TerraformExecutionRole
        aws sts assume-role \
            --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
            --role-session-name "setup-terraform-role" \
            --output json > /tmp/${env}-creds.json
        
        # Extract credentials
        export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' /tmp/${env}-creds.json)
        export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' /tmp/${env}-creds.json)
        export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' /tmp/${env}-creds.json)
        
        # Create TerraformExecutionRole
        aws iam create-role \
            --role-name TerraformExecutionRole \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "AWS": "arn:aws:iam::'$ROOT_ACCOUNT_ID':root"
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }' || echo "Role already exists"
        
        # Attach PowerUserAccess policy
        aws iam attach-role-policy \
            --role-name TerraformExecutionRole \
            --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
        
        # Cleanup credentials
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        rm -f /tmp/${env}-creds.json
    done
    
    echo -e "${GREEN}✅ Cross-account roles created${NC}"
}

create_terraform_vars() {
    echo -e "${YELLOW}Creating terraform.tfvars...${NC}"
    
    cat > ../terraform/terraform.tfvars <<EOF
# Multi-Account Configuration
target_environment = "dev"  # Change this for each deployment

# Account IDs
dev_account_id        = "$DEV_ACCOUNT_ID"
staging_account_id    = "$STAGING_ACCOUNT_ID"
production_account_id = "$PRODUCTION_ACCOUNT_ID"

# Existing configuration
allowed_account_id = "$ROOT_ACCOUNT_ID"
cluster_name      = "tbyte-dev"  # Will be overridden by environment config
region           = "eu-central-1"

# GitHub configuration (add your values)
git_repo_url                    = "https://github.com/YOUR_USERNAME/tbyte.git"
github_actions_role_arn         = "arn:aws:iam::$ROOT_ACCOUNT_ID:role/GitHubActionsEKSRole"
github_app_id                   = "YOUR_GITHUB_APP_ID"
github_app_installation_id     = "YOUR_GITHUB_APP_INSTALLATION_ID"
github_app_private_key          = "YOUR_GITHUB_APP_PRIVATE_KEY"
EOF
    
    echo -e "${GREEN}✅ terraform.tfvars created${NC}"
}

deploy_environment() {
    local env=$1
    local account_id=$2
    
    echo -e "${YELLOW}Deploying $env environment to account $account_id...${NC}"
    
    cd ../terraform
    
    # Update target_environment in tfvars
    sed -i '' "s/target_environment = .*/target_environment = \"$env\"/" terraform.tfvars
    
    # Initialize if needed
    terraform init
    
    # Plan
    terraform plan -out=$env.tfplan
    
    # Apply
    terraform apply $env.tfplan
    
    # Cleanup
    rm -f $env.tfplan
    
    echo -e "${GREEN}✅ $env environment deployed${NC}"
}

main() {
    echo "🚀 Multi-Account Setup for TByte Assessment"
    echo "==========================================="
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq not found${NC}"
        exit 1
    fi
    
    # Verify root account access
    export AWS_PROFILE=$ROOT_PROFILE
    CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    
    if [ "$CURRENT_ACCOUNT" != "$ROOT_ACCOUNT_ID" ]; then
        echo -e "${RED}❌ Not connected to root account${NC}"
        echo "Current: $CURRENT_ACCOUNT, Expected: $ROOT_ACCOUNT_ID"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Connected to root account: $ROOT_ACCOUNT_ID${NC}"
    
    # Ask for confirmation
    echo ""
    echo "This will:"
    echo "1. Create 3 new AWS accounts via Organizations"
    echo "2. Set up cross-account IAM roles"
    echo "3. Create Terraform configuration"
    echo "4. Deploy dev environment"
    echo ""
    echo "Estimated cost: ~$150/month per environment"
    echo ""
    read -p "Continue? (y/N): " confirm
    
    if [[ $confirm != [yY] ]]; then
        echo "Aborted"
        exit 0
    fi
    
    # Execute setup
    create_aws_accounts
    setup_cross_account_roles
    create_terraform_vars
    
    echo ""
    echo -e "${GREEN}🎉 Multi-account setup complete!${NC}"
    echo ""
    echo "Account IDs:"
    echo "- DEV: $DEV_ACCOUNT_ID"
    echo "- STAGING: $STAGING_ACCOUNT_ID"
    echo "- PRODUCTION: $PRODUCTION_ACCOUNT_ID"
    echo ""
    echo "Next steps:"
    echo "1. Update terraform.tfvars with your GitHub App details"
    echo "2. Deploy environments:"
    echo "   cd terraform"
    echo "   terraform apply  # Deploys to DEV"
    echo ""
    echo "3. For other environments, change target_environment in tfvars"
}

case "${1:-}" in
    -h|--help)
        echo "Multi-Account Setup Script"
        echo ""
        echo "This script creates 3 AWS accounts and sets up multi-account"
        echo "environment promotion for the TByte assessment."
        echo ""
        echo "Prerequisites:"
        echo "- AWS CLI configured with oth_infra profile"
        echo "- AWS Organizations enabled"
        echo "- jq installed"
        exit 0
        ;;
    *)
        main
        ;;
esac
