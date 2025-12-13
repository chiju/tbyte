#!/bin/bash
set -e

echo "🧪 Testing Multi-Account Environment Promotion"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Account profiles
ROOT_PROFILE="oth_infra"
DEV_PROFILE="dev"
STAGING_PROFILE="staging"
PRODUCTION_PROFILE="production"

test_account() {
    local env=$1
    local profile=$2
    local cluster_name="tbyte-${env}-cluster"
    
    echo -e "${YELLOW}Testing $env account (profile: $profile)...${NC}"
    
    # Switch to account profile
    export AWS_PROFILE=$profile
    
    # Check AWS connectivity
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to $env account${NC}"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ Connected to $env account: $account_id${NC}"
    
    # Check EKS cluster
    if aws eks describe-cluster --name $cluster_name >/dev/null 2>&1; then
        echo -e "${GREEN}✅ EKS cluster exists: $cluster_name${NC}"
    else
        echo -e "${RED}❌ EKS cluster missing: $cluster_name${NC}"
        return 1
    fi
    
    # Update kubeconfig and test
    aws eks update-kubeconfig --name $cluster_name --region eu-central-1 >/dev/null 2>&1
    
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Kubernetes connectivity working${NC}"
    else
        echo -e "${RED}❌ Cannot connect to Kubernetes${NC}"
        return 1
    fi
    
    # Check if application is deployed
    local pods=$(kubectl get pods -l app.kubernetes.io/name=frontend --no-headers 2>/dev/null | wc -l)
    if [ $pods -gt 0 ]; then
        echo -e "${GREEN}✅ Application deployed ($pods frontend pods)${NC}"
    else
        echo -e "${YELLOW}⚠️  No application deployed yet${NC}"
    fi
    
    echo ""
}

test_ecr_access() {
    echo -e "${YELLOW}Testing ECR cross-account access...${NC}"
    
    # Test from each account
    for env in dev staging production; do
        local profile=$env
        export AWS_PROFILE=$profile
        
        echo "Testing ECR access from $env account..."
        
        # Try to list repositories in shared services account
        export AWS_PROFILE=$ROOT_PROFILE
        local ecr_registry=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com
        
        export AWS_PROFILE=$profile
        if aws ecr describe-repositories --registry-id $(echo $ecr_registry | cut -d. -f1) >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $env can access ECR${NC}"
        else
            echo -e "${RED}❌ $env cannot access ECR${NC}"
        fi
    done
    
    echo ""
}

show_deployment_status() {
    echo -e "${YELLOW}Deployment status across accounts:${NC}"
    echo "=================================="
    
    for env in dev staging production; do
        local profile=$env
        local cluster_name="tbyte-${env}-cluster"
        
        export AWS_PROFILE=$profile
        aws eks update-kubeconfig --name $cluster_name --region eu-central-1 >/dev/null 2>&1
        
        echo "=== $env ACCOUNT ==="
        kubectl get pods -o wide 2>/dev/null || echo "No pods found"
        echo ""
    done
}

main() {
    echo "🚀 Multi-Account Environment Promotion Test"
    echo "==========================================="
    
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found${NC}"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found${NC}"
        exit 1
    fi
    
    # Test each account
    FAILED_TESTS=0
    
    if ! test_account "dev" $DEV_PROFILE; then
        ((FAILED_TESTS++))
    fi
    
    if ! test_account "staging" $STAGING_PROFILE; then
        ((FAILED_TESTS++))
    fi
    
    if ! test_account "production" $PRODUCTION_PROFILE; then
        ((FAILED_TESTS++))
    fi
    
    # Test ECR access
    test_ecr_access
    
    # Show deployment status
    show_deployment_status
    
    echo "==========================================="
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All multi-account tests passed!${NC}"
        echo ""
        echo "Ready for environment promotion:"
        echo "1. Push to main → DEV auto-deploy"
        echo "2. Manual trigger → STAGING deploy"
        echo "3. Manual trigger → PRODUCTION deploy"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS test(s) failed${NC}"
        exit 1
    fi
}

# Parse arguments
case "${1:-}" in
    --dev)
        test_account "dev" $DEV_PROFILE
        ;;
    --staging)
        test_account "staging" $STAGING_PROFILE
        ;;
    --production)
        test_account "production" $PRODUCTION_PROFILE
        ;;
    --status)
        show_deployment_status
        ;;
    --ecr)
        test_ecr_access
        ;;
    -h|--help)
        echo "Multi-Account Test Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --dev          Test DEV account only"
        echo "  --staging      Test STAGING account only"
        echo "  --production   Test PRODUCTION account only"
        echo "  --status       Show deployment status"
        echo "  --ecr          Test ECR access"
        echo "  -h, --help     Show this help"
        exit 0
        ;;
    *)
        main
        ;;
esac
