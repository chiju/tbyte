#!/bin/bash
set -e

echo "🏗️ Setting up Multi-Account Environment Promotion"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Account configuration
ROOT_PROFILE="oth_infra"
DEV_ACCOUNT_ID=""
STAGING_ACCOUNT_ID=""
PRODUCTION_ACCOUNT_ID=""

setup_account() {
    local account_name=$1
    local account_id=$2
    local cluster_name="tbyte-${account_name}-cluster"
    
    echo -e "${YELLOW}Setting up $account_name account ($account_id)...${NC}"
    
    # Switch to account profile
    export AWS_PROFILE="${account_name}"
    
    # Create EKS cluster
    echo "Creating EKS cluster: $cluster_name"
    
    # Use Terraform to create cluster
    cd terraform/
    
    # Create workspace for this environment
    terraform workspace new $account_name 2>/dev/null || terraform workspace select $account_name
    
    # Deploy infrastructure
    terraform apply -var="cluster_name=$cluster_name" -var="environment=$account_name" -auto-approve
    
    # Update kubeconfig
    aws eks update-kubeconfig --name $cluster_name --region eu-central-1
    
    # Install ArgoCD
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo -e "${GREEN}✅ $account_name account setup complete${NC}"
    cd ..
}

create_cross_account_roles() {
    echo -e "${YELLOW}Creating cross-account IAM roles...${NC}"
    
    # Switch to root account
    export AWS_PROFILE=$ROOT_PROFILE
    
    # Create OIDC provider (if not exists)
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
        2>/dev/null || echo "OIDC provider already exists"
    
    # Create roles for each account
    for env in dev staging production; do
        echo "Creating role for $env account..."
        
        # Create trust policy
        cat > /tmp/${env}-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
                    "token.actions.githubusercontent.com:sub": "repo:$(git config --get remote.origin.url | sed 's/.*github.com[:/]//;s/.git$//')/*"
                }
            }
        }
    ]
}
EOF
        
        # Create role
        aws iam create-role \
            --role-name "GitHubActions-${env^}Account" \
            --assume-role-policy-document file:///tmp/${env}-trust-policy.json \
            2>/dev/null || echo "Role already exists"
        
        # Attach policies
        aws iam attach-role-policy \
            --role-name "GitHubActions-${env^}Account" \
            --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
    done
    
    echo -e "${GREEN}✅ Cross-account roles created${NC}"
}

setup_github_secrets() {
    echo -e "${YELLOW}Setting up GitHub secrets...${NC}"
    
    # Get account IDs
    export AWS_PROFILE=$ROOT_PROFILE
    ROOT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Set GitHub secrets
    gh secret set SHARED_SERVICES_ROLE_ARN -b "arn:aws:iam::${ROOT_ACCOUNT_ID}:role/GitHubActionsEKSRole"
    gh secret set DEV_ACCOUNT_ROLE_ARN -b "arn:aws:iam::${DEV_ACCOUNT_ID}:role/GitHubActions-DevAccount"
    gh secret set STAGING_ACCOUNT_ROLE_ARN -b "arn:aws:iam::${STAGING_ACCOUNT_ID}:role/GitHubActions-StagingAccount"
    gh secret set PRODUCTION_ACCOUNT_ROLE_ARN -b "arn:aws:iam::${PRODUCTION_ACCOUNT_ID}:role/GitHubActions-ProductionAccount"
    
    echo -e "${GREEN}✅ GitHub secrets configured${NC}"
}

main() {
    echo "🚀 Multi-Account Setup for TByte"
    echo "================================"
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found${NC}"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform not found${NC}"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI not found${NC}"
        exit 1
    fi
    
    # Get account IDs
    echo "Please provide the AWS Account IDs:"
    read -p "DEV Account ID: " DEV_ACCOUNT_ID
    read -p "STAGING Account ID: " STAGING_ACCOUNT_ID
    read -p "PRODUCTION Account ID: " PRODUCTION_ACCOUNT_ID
    
    echo "Account Configuration:"
    echo "- ROOT (Shared Services): $ROOT_PROFILE"
    echo "- DEV: $DEV_ACCOUNT_ID"
    echo "- STAGING: $STAGING_ACCOUNT_ID"
    echo "- PRODUCTION: $PRODUCTION_ACCOUNT_ID"
    
    read -p "Continue? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "Aborted"
        exit 0
    fi
    
    # Setup accounts
    setup_account "dev" $DEV_ACCOUNT_ID
    setup_account "staging" $STAGING_ACCOUNT_ID
    setup_account "production" $PRODUCTION_ACCOUNT_ID
    
    # Create cross-account roles
    create_cross_account_roles
    
    # Setup GitHub secrets
    setup_github_secrets
    
    echo "================================"
    echo -e "${GREEN}🎉 Multi-account setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Configure AWS profiles for each account"
    echo "2. Test the promotion pipeline"
    echo "3. Set up GitHub environment protection rules"
}

show_help() {
    echo "Multi-Account Setup Script"
    echo ""
    echo "Prerequisites:"
    echo "- AWS CLI configured with root account profile: $ROOT_PROFILE"
    echo "- Terraform installed"
    echo "- GitHub CLI authenticated"
    echo "- 3 AWS accounts (dev, staging, production)"
    echo ""
    echo "Usage: $0"
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac
