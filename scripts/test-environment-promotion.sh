#!/bin/bash
set -e

echo "🧪 Testing Environment Promotion Pipeline"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_dev_deployment() {
    echo -e "${YELLOW}Testing DEV deployment...${NC}"
    
    # Check if dev namespace exists
    if kubectl get namespace dev >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DEV namespace exists${NC}"
    else
        echo -e "${RED}❌ DEV namespace missing${NC}"
        return 1
    fi
    
    # Check if pods are running
    if kubectl get pods -n dev -l app=tbyte-frontend --no-headers | grep -q Running; then
        echo -e "${GREEN}✅ Frontend running in DEV${NC}"
    else
        echo -e "${RED}❌ Frontend not running in DEV${NC}"
        return 1
    fi
    
    if kubectl get pods -n dev -l app=tbyte-backend --no-headers | grep -q Running; then
        echo -e "${GREEN}✅ Backend running in DEV${NC}"
    else
        echo -e "${RED}❌ Backend not running in DEV${NC}"
        return 1
    fi
}

test_staging_deployment() {
    echo -e "${YELLOW}Testing STAGING deployment...${NC}"
    
    # Check if staging namespace exists
    if kubectl get namespace staging >/dev/null 2>&1; then
        echo -e "${GREEN}✅ STAGING namespace exists${NC}"
    else
        echo -e "${RED}❌ STAGING namespace missing${NC}"
        return 1
    fi
    
    # Check replica count (should be 2 in staging)
    FRONTEND_REPLICAS=$(kubectl get deployment tbyte-staging-frontend -n staging -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [ "$FRONTEND_REPLICAS" = "2" ]; then
        echo -e "${GREEN}✅ Frontend has correct replica count in STAGING (2)${NC}"
    else
        echo -e "${RED}❌ Frontend replica count incorrect in STAGING: $FRONTEND_REPLICAS${NC}"
        return 1
    fi
}

test_production_deployment() {
    echo -e "${YELLOW}Testing PRODUCTION deployment...${NC}"
    
    # Check if production pods are running (default namespace)
    if kubectl get pods -l app=tbyte-frontend --no-headers | grep -q Running; then
        echo -e "${GREEN}✅ Frontend running in PRODUCTION${NC}"
    else
        echo -e "${RED}❌ Frontend not running in PRODUCTION${NC}"
        return 1
    fi
    
    # Check replica count (should be 2+ in production)
    FRONTEND_REPLICAS=$(kubectl get deployment tbyte-production-frontend -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [ "$FRONTEND_REPLICAS" -ge "2" ]; then
        echo -e "${GREEN}✅ Frontend has sufficient replicas in PRODUCTION ($FRONTEND_REPLICAS)${NC}"
    else
        echo -e "${RED}❌ Frontend replica count too low in PRODUCTION: $FRONTEND_REPLICAS${NC}"
        return 1
    fi
}

test_image_consistency() {
    echo -e "${YELLOW}Testing image consistency across environments...${NC}"
    
    # Get image tags from each environment
    DEV_IMAGE=$(kubectl get deployment tbyte-dev-frontend -n dev -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "none")
    STAGING_IMAGE=$(kubectl get deployment tbyte-staging-frontend -n staging -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "none")
    PROD_IMAGE=$(kubectl get deployment tbyte-production-frontend -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "none")
    
    echo "DEV image: $DEV_IMAGE"
    echo "STAGING image: $STAGING_IMAGE"
    echo "PRODUCTION image: $PROD_IMAGE"
    
    # Extract image tags
    DEV_TAG=$(echo $DEV_IMAGE | cut -d':' -f2)
    STAGING_TAG=$(echo $STAGING_IMAGE | cut -d':' -f2)
    PROD_TAG=$(echo $PROD_IMAGE | cut -d':' -f2)
    
    if [ "$DEV_TAG" = "$STAGING_TAG" ] && [ "$STAGING_TAG" = "$PROD_TAG" ]; then
        echo -e "${GREEN}✅ Same image tag across all environments: $DEV_TAG${NC}"
    else
        echo -e "${YELLOW}⚠️  Different image tags across environments (expected during promotion)${NC}"
    fi
}

test_environment_configs() {
    echo -e "${YELLOW}Testing environment-specific configurations...${NC}"
    
    # Check resource limits differ between environments
    DEV_CPU=$(kubectl get deployment tbyte-dev-frontend -n dev -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "none")
    STAGING_CPU=$(kubectl get deployment tbyte-staging-frontend -n staging -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "none")
    
    echo "DEV CPU request: $DEV_CPU"
    echo "STAGING CPU request: $STAGING_CPU"
    
    if [ "$DEV_CPU" != "$STAGING_CPU" ]; then
        echo -e "${GREEN}✅ Different resource configs per environment${NC}"
    else
        echo -e "${YELLOW}⚠️  Same resource configs (might be intentional)${NC}"
    fi
}

# Main test execution
main() {
    echo "🚀 Starting Environment Promotion Tests"
    echo "========================================"
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
    
    # Run tests
    FAILED_TESTS=0
    
    if ! test_dev_deployment; then
        ((FAILED_TESTS++))
    fi
    
    if ! test_staging_deployment; then
        ((FAILED_TESTS++))
    fi
    
    if ! test_production_deployment; then
        ((FAILED_TESTS++))
    fi
    
    test_image_consistency
    test_environment_configs
    
    echo "========================================"
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All environment promotion tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ $FAILED_TESTS test(s) failed${NC}"
        exit 1
    fi
}

# Help function
show_help() {
    echo "Environment Promotion Test Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --dev          Test only DEV environment"
    echo "  --staging      Test only STAGING environment"
    echo "  --prod         Test only PRODUCTION environment"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test all environments"
    echo "  $0 --dev             # Test only DEV"
    echo "  $0 --staging         # Test only STAGING"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --dev)
        test_dev_deployment
        exit $?
        ;;
    --staging)
        test_staging_deployment
        exit $?
        ;;
    --prod)
        test_production_deployment
        exit $?
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
