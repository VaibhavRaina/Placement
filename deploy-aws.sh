#!/bin/bash

# AWS Deployment Script for Placement Portal
set -e

echo "🚀 Starting AWS Infrastructure Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Check dependencies
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}AWS CLI not found. Please install AWS CLI first.${NC}"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Terraform not found. Please install Terraform first.${NC}"
        exit 1
    fi
    

    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker not found. Please install Docker first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies found${NC}"
}

# Configure AWS credentials
configure_aws() {
    echo -e "${BLUE}Configuring AWS...${NC}"
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${YELLOW}AWS credentials not configured. Please run 'aws configure' first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ AWS credentials configured${NC}"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    echo -e "${BLUE}Deploying Terraform infrastructure...${NC}"
    
    cd infrastructure
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -out=tfplan
    
    # Apply deployment
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    terraform apply tfplan
    
    # Get outputs
    echo -e "${BLUE}Getting infrastructure outputs...${NC}"
    BACKEND_ECR_URL=$(terraform output -raw backend_repository_url)
    FRONTEND_ECR_URL=$(terraform output -raw frontend_repository_url)
    DOCDB_ENDPOINT=$(terraform output -raw docdb_cluster_endpoint)
    ALB_DNS=$(terraform output -raw load_balancer_dns)
    
    cd ..
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo -e "${BLUE}Backend ECR: ${BACKEND_ECR_URL}${NC}"
    echo -e "${BLUE}Frontend ECR: ${FRONTEND_ECR_URL}${NC}"
    echo -e "${BLUE}DocumentDB Endpoint: ${DOCDB_ENDPOINT}${NC}"
    echo -e "${BLUE}Load Balancer DNS: ${ALB_DNS}${NC}"
}

# Wait for infrastructure to be ready
wait_for_infrastructure() {
    echo -e "${BLUE}Waiting for infrastructure to be ready...${NC}"

    # Wait for load balancer to be active
    echo -e "${YELLOW}Waiting for load balancer to be active...${NC}"
    aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --names placement-portal-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region ${AWS_REGION})

    echo -e "${GREEN}✅ Infrastructure is ready${NC}"
}

# Build and push Docker images
build_and_push_images() {
    echo -e "${BLUE}Building and pushing Docker images...${NC}"
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${BACKEND_ECR_URL%/*}
    
    # Build and push backend
    echo -e "${YELLOW}Building backend image...${NC}"
    cd backend
    docker build -t ${BACKEND_ECR_URL}:latest .
    docker push ${BACKEND_ECR_URL}:latest
    cd ..
    
    # Build and push frontend
    echo -e "${YELLOW}Building frontend image...${NC}"
    cd frontend
    docker build -t ${FRONTEND_ECR_URL}:latest .
    docker push ${FRONTEND_ECR_URL}:latest
    cd ..
    
    echo -e "${GREEN}✅ Docker images built and pushed${NC}"
}

# Deploy applications to EC2
deploy_to_ec2() {
    echo -e "${BLUE}Deploying applications to EC2 instances...${NC}"

    # Check if this is initial deployment or update
    BACKEND_INSTANCE_ID=$(aws ec2 describe-instances \
        --filters 'Name=tag:Name,Values=placement-portal-backend' 'Name=instance-state-name,Values=running' \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text --region ${AWS_REGION} 2>/dev/null)

    if [ "$BACKEND_INSTANCE_ID" != "None" ] && [ -n "$BACKEND_INSTANCE_ID" ]; then
        echo -e "${YELLOW}Infrastructure exists - using EC2 deployment script for updates${NC}"
        ./deploy-ec2.sh
    else
        echo -e "${YELLOW}Initial deployment - infrastructure will be created by Terraform${NC}"
        echo -e "${BLUE}Building and pushing initial images...${NC}"

        # Build and push images for initial deployment
        build_and_push_images

        echo -e "${GREEN}✅ Initial images built and pushed${NC}"
        echo -e "${YELLOW}Note: Applications will be deployed when instances launch${NC}"
    fi

    echo -e "${GREEN}✅ EC2 deployment process completed${NC}"
}

# Check deployment status
check_deployment_status() {
    echo -e "${BLUE}Checking deployment status...${NC}"

    # Check EC2 instances
    echo -e "${YELLOW}Backend Instance Status:${NC}"
    aws ec2 describe-instances \
        --filters 'Name=tag:Name,Values=placement-portal-backend' 'Name=instance-state-name,Values=running' \
        --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
        --output table --region ${AWS_REGION}

    echo -e "${YELLOW}Frontend Instance Status:${NC}"
    aws ec2 describe-instances \
        --filters 'Name=tag:Name,Values=placement-portal-frontend' 'Name=instance-state-name,Values=running' \
        --query 'Reservations[0].Instances[0].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
        --output table --region ${AWS_REGION}

    # Check target group health
    echo -e "${YELLOW}Target Group Health:${NC}"
    aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names placement-portal-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region ${AWS_REGION}) --region ${AWS_REGION} --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}' --output table

    echo -e "${GREEN}✅ Deployment status checked${NC}"
}

# Get service information
get_service_info() {
    echo -e "${BLUE}Getting service information...${NC}"

    echo -e "${YELLOW}Load Balancer Information:${NC}"
    aws elbv2 describe-load-balancers --names placement-portal-alb --region ${AWS_REGION} --query 'LoadBalancers[0].{DNSName:DNSName,State:State.Code,Type:Type}' --output table

    echo -e "${YELLOW}Jenkins Information:${NC}"
    JENKINS_IP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-jenkins-eip" --query 'Addresses[0].PublicIp' --output text --region ${AWS_REGION})
    echo "Jenkins URL: http://${JENKINS_IP}:8080"

    echo -e "${YELLOW}SonarQube Information:${NC}"
    SONARQUBE_IP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-sonarqube-eip" --query 'Addresses[0].PublicIp' --output text --region ${AWS_REGION})
    echo "SonarQube URL: http://${SONARQUBE_IP}:9000"

    echo -e "${GREEN}Application URL: http://${ALB_DNS}${NC}"
}

# Main deployment function
main() {
    echo -e "${GREEN}=== AWS Placement Portal Deployment ===${NC}"

    check_dependencies
    configure_aws
    deploy_terraform
    wait_for_infrastructure
    deploy_to_ec2
    check_deployment_status
    get_service_info

    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${BLUE}Don't forget to update your DNS records to point to the load balancer${NC}"
}

# Run main function
main "$@"
