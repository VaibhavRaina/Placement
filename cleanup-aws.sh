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

cleanup_ec2_instances() {
    echo -e "${BLUE}Cleaning up EC2 Auto Scaling Groups...${NC}"

    # Set desired capacity to 0 for all ASGs
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name placement-portal-backend-asg --desired-capacity 0 --min-size 0 2>/dev/null || echo "Backend ASG not found"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name placement-portal-frontend-asg --desired-capacity 0 --min-size 0 2>/dev/null || echo "Frontend ASG not found"

    echo "Waiting for instances to terminate..."
    sleep 30

    echo -e "${GREEN}✅ EC2 instances cleaned up${NC}"
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

    cleanup_ec2_instances
    cleanup_docker_images
    cleanup_terraform

    echo -e "${GREEN}🧹 Cleanup completed!${NC}"
}

# Run main function
main "$@"
