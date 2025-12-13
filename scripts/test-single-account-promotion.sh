#!/bin/bash
set -e

echo "🧪 Testing Single-Account Environment Promotion"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_environment() {
    local env=$1
    local namespace=$2
    
    echo -e "${YELLOW}Testing $env environment (namespace: $namespace)...${NC}"
    
    # Check namespace exists
    if kubectl get namespace $namespace >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $env namespace exists${NC}"
    else
        echo -e "${RED}❌ $env namespace missing${NC}"
        return 1
    fi
    
    # Check ArgoCD app exists
    if kubectl get application tbyte-$env -n argocd >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $env ArgoCD application exists${NC}"
    else
        echo -e "${RED}❌ $env ArgoCD application missing${NC}"
        return 1
    fi
    
    # Check pods are running
    local frontend_pods=$(kubectl get pods -n $namespace -l app.kubernetes.io/name=frontend --no-headers 2>/dev/null | wc -l)
    local backend_pods=$(kubectl get pods -n $namespace -l app.kubernetes.io/name=backend --no-headers 2>/dev/null | wc -l)
    
    if [ $frontend_pods -gt 0 ]; then
        echo -e "${GREEN}✅ Frontend pods running in $env ($frontend_pods)${NC}"
    else
        echo -e "${RED}❌ No frontend pods in $env${NC}"
    fi
    
    if [ $backend_pods -gt 0 ]; then
        echo -e "${GREEN}✅ Backend pods running in $env ($backend_pods)${NC}"
    else
        echo -e "${RED}❌ No backend pods in $env${NC}"
    fi
}

show_image_tags() {
    echo -e "${YELLOW}Image tags across environments:${NC}"
    
    for env in dev staging production; do
        local namespace=$env
        if [ "$env" = "production" ]; then
            namespace="prod"
        fi
        
        local app_name="tbyte-$env"
        
        echo "=== $env ==="
        kubectl get application $app_name -n argocd -o jsonpath='{.spec.source.helm.parameters}' 2>/dev/null | jq -r '.[] | select(.name | contains("image.tag")) | "\(.name): \(.value)"' 2>/dev/null || echo "No image tag found"
    done
}

main() {
    echo "🚀 Single-Account Environment Promotion Test"
    echo "============================================"
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
    
    # Test each environment
    test_environment "dev" "dev"
    test_environment "staging" "staging" 
    test_environment "production" "prod"
    
    # Show image consistency
    show_image_tags
    
    echo "============================================"
    echo -e "${GREEN}🎉 Environment promotion test completed!${NC}"
}

# Parse arguments
case "${1:-}" in
    --dev)
        test_environment "dev" "dev"
        ;;
    --staging)
        test_environment "staging" "staging"
        ;;
    --production)
        test_environment "production" "prod"
        ;;
    --images)
        show_image_tags
        ;;
    *)
        main
        ;;
esac
