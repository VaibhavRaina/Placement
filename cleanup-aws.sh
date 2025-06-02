#!/bin/bash

# AWS Infrastructure Cleanup Script
set -e

echo "🧹 Starting AWS Infrastructure Cleanup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}

cleanup_k8s() {
    echo -e "${BLUE}Cleaning up Kubernetes resources...${NC}"
    
    # Delete in reverse order
    kubectl delete -f k8s/ingress.yaml --ignore-not-found=true
    kubectl delete -f k8s/frontend-service.yaml --ignore-not-found=true
    kubectl delete -f k8s/frontend-deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s/backend-service.yaml --ignore-not-found=true
    kubectl delete -f k8s/backend-deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s/mongodb-service.yaml --ignore-not-found=true
    kubectl delete -f k8s/mongodb-deployment.yaml --ignore-not-found=true
    kubectl delete -f k8s/mongodb-pvc.yaml --ignore-not-found=true
    kubectl delete -f k8s/secrets.yaml --ignore-not-found=true
    
    # Clean up staging namespace
    kubectl delete namespace staging --ignore-not-found=true
    
    echo -e "${GREEN}✅ Kubernetes resources cleaned up${NC}"
}

cleanup_docker_images() {
    echo -e "${BLUE}Cleaning up local Docker images...${NC}"
    
    # Remove local images (optional)
    docker images | grep placement | awk '{print $3}' | xargs -r docker rmi -f
    
    echo -e "${GREEN}✅ Local Docker images cleaned up${NC}"
}

cleanup_terraform() {
    echo -e "${BLUE}Destroying Terraform infrastructure...${NC}"
    
    cd infrastructure
    
    # Confirm destruction
    echo -e "${YELLOW}This will destroy all AWS infrastructure. Are you sure? (yes/no)${NC}"
    read -r confirmation
    
    if [[ $confirmation == "yes" ]]; then
        terraform destroy -auto-approve
        echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
    else
        echo -e "${YELLOW}Infrastructure destruction cancelled${NC}"
    fi
    
    cd ..
}

main() {
    echo -e "${GREEN}=== AWS Infrastructure Cleanup ===${NC}"
    
    cleanup_k8s
    cleanup_docker_images
    cleanup_terraform
    
    echo -e "${GREEN}🧹 Cleanup completed!${NC}"
}

# Run main function
main "$@"
