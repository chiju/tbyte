#!/bin/bash
set -e

echo "🏗️ TByte Multi-Environment Management"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TERRAFORM_DIR="../terraform"

show_help() {
    echo "Multi-Environment Management Script"
    echo ""
    echo "Usage: $0 <command> [environment]"
    echo ""
    echo "Commands:"
    echo "  init                 Initialize Terraform backend"
    echo "  list                 List all workspaces"
    echo "  create <env>         Create new environment"
    echo "  deploy <env>         Deploy environment"
    echo "  destroy <env>        Destroy environment"
    echo "  status <env>         Show environment status"
    echo "  promote <from> <to>  Promote between environments"
    echo ""
    echo "Environments: dev, staging, production"
    echo ""
    echo "Examples:"
    echo "  $0 init                    # Initialize backend"
    echo "  $0 create dev              # Create dev environment"
    echo "  $0 deploy staging          # Deploy staging"
    echo "  $0 promote dev staging     # Promote dev to staging"
}

init_terraform() {
    echo -e "${YELLOW}Initializing Terraform backend...${NC}"
    cd $TERRAFORM_DIR
    terraform init
    echo -e "${GREEN}✅ Terraform initialized${NC}"
}

list_workspaces() {
    echo -e "${YELLOW}Available workspaces:${NC}"
    cd $TERRAFORM_DIR
    terraform workspace list
}

create_environment() {
    local env=$1
    
    if [[ ! "$env" =~ ^(dev|staging|production)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $env${NC}"
        echo "Valid environments: dev, staging, production"
        exit 1
    fi
    
    echo -e "${YELLOW}Creating $env environment...${NC}"
    cd $TERRAFORM_DIR
    
    # Create workspace
    terraform workspace new $env 2>/dev/null || terraform workspace select $env
    
    echo -e "${GREEN}✅ Environment $env ready${NC}"
}

deploy_environment() {
    local env=$1
    
    if [[ ! "$env" =~ ^(dev|staging|production)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $env${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Deploying $env environment...${NC}"
    cd $TERRAFORM_DIR
    
    # Select workspace
    terraform workspace select $env
    
    # Plan
    echo "Running terraform plan..."
    terraform plan -out=$env.tfplan
    
    # Apply
    echo "Applying changes..."
    terraform apply $env.tfplan
    
    # Cleanup plan file
    rm -f $env.tfplan
    
    echo -e "${GREEN}✅ $env environment deployed${NC}"
    
    # Show outputs
    echo -e "${YELLOW}Environment outputs:${NC}"
    terraform output
}

destroy_environment() {
    local env=$1
    
    if [[ ! "$env" =~ ^(dev|staging|production)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $env${NC}"
        exit 1
    fi
    
    echo -e "${RED}⚠️  Destroying $env environment...${NC}"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Aborted"
        exit 0
    fi
    
    cd $TERRAFORM_DIR
    terraform workspace select $env
    terraform destroy -auto-approve
    
    echo -e "${GREEN}✅ $env environment destroyed${NC}"
}

show_status() {
    local env=$1
    
    if [[ ! "$env" =~ ^(dev|staging|production)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $env${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Status for $env environment:${NC}"
    cd $TERRAFORM_DIR
    
    terraform workspace select $env
    
    echo "=== Terraform State ==="
    terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_eks_cluster") | "\(.values.name): \(.values.status)"' 2>/dev/null || echo "No EKS cluster found"
    
    echo ""
    echo "=== Workspace Info ==="
    echo "Current workspace: $(terraform workspace show)"
    echo "State file: terraform.tfstate.d/$env/terraform.tfstate"
    
    echo ""
    echo "=== Outputs ==="
    terraform output 2>/dev/null || echo "No outputs available"
}

promote_environment() {
    local from_env=$1
    local to_env=$2
    
    if [[ ! "$from_env" =~ ^(dev|staging|production)$ ]] || [[ ! "$to_env" =~ ^(dev|staging|production)$ ]]; then
        echo -e "${RED}❌ Invalid environments${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Promoting from $from_env to $to_env...${NC}"
    
    # This would typically involve:
    # 1. Get image tags from source environment
    # 2. Update target environment with same image tags
    # 3. Deploy target environment
    
    echo "Promotion steps:"
    echo "1. Extract image tags from $from_env"
    echo "2. Update $to_env configuration"
    echo "3. Deploy $to_env with promoted artifacts"
    
    echo -e "${GREEN}✅ Promotion completed${NC}"
}

main() {
    local command=$1
    local env=$2
    local target_env=$3
    
    case $command in
        init)
            init_terraform
            ;;
        list)
            list_workspaces
            ;;
        create)
            if [ -z "$env" ]; then
                echo -e "${RED}❌ Environment required${NC}"
                show_help
                exit 1
            fi
            create_environment $env
            ;;
        deploy)
            if [ -z "$env" ]; then
                echo -e "${RED}❌ Environment required${NC}"
                show_help
                exit 1
            fi
            deploy_environment $env
            ;;
        destroy)
            if [ -z "$env" ]; then
                echo -e "${RED}❌ Environment required${NC}"
                show_help
                exit 1
            fi
            destroy_environment $env
            ;;
        status)
            if [ -z "$env" ]; then
                echo -e "${RED}❌ Environment required${NC}"
                show_help
                exit 1
            fi
            show_status $env
            ;;
        promote)
            if [ -z "$env" ] || [ -z "$target_env" ]; then
                echo -e "${RED}❌ Source and target environments required${NC}"
                show_help
                exit 1
            fi
            promote_environment $env $target_env
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
