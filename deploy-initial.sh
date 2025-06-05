#!/bin/bash

# Initial Deployment Script for Placement Portal
# This script handles the first-time deployment when infrastructure doesn't exist yet

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${GREEN}🚀 Initial Deployment for Placement Portal${NC}"
echo "=============================================="

# Check if this is truly an initial deployment
print_status "Checking if infrastructure already exists..."

if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names placement-portal-backend-asg --region us-east-1 >/dev/null 2>&1; then
    print_warning "Infrastructure already exists! Use ./deploy-ec2.sh for updates instead."
    echo ""
    echo "Available deployment options:"
    echo "  ./deploy-aws.sh    - Full infrastructure deployment"
    echo "  ./deploy-ec2.sh    - Application updates only"
    echo ""
    exit 1
fi

print_success "This appears to be an initial deployment"

# Step 1: Deploy infrastructure with Terraform
print_status "Step 1: Deploying infrastructure with Terraform..."
cd infrastructure

if [ ! -f ".terraform/terraform.tfstate" ]; then
    print_status "Initializing Terraform..."
    terraform init
fi

print_status "Planning infrastructure deployment..."
terraform plan

echo ""
print_warning "About to deploy AWS infrastructure. This will create:"
echo "  - VPC with public/private subnets"
echo "  - Application Load Balancer"
echo "  - Auto Scaling Groups for frontend/backend"
echo "  - DocumentDB cluster"
echo "  - Jenkins and SonarQube instances"
echo "  - ECR repositories"
echo ""

read -p "Continue with infrastructure deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 1
fi

print_status "Applying Terraform configuration..."
terraform apply -auto-approve

print_success "Infrastructure deployed successfully!"

# Get outputs
ALB_DNS=$(terraform output -raw load_balancer_dns)
BACKEND_ECR=$(terraform output -raw backend_repository_url)
FRONTEND_ECR=$(terraform output -raw frontend_repository_url)

cd ..

# Step 2: Build and push initial images
print_status "Step 2: Building and pushing Docker images..."

# Check AWS CLI configuration
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS CLI not configured. Please run 'aws configure'"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"

# ECR login
print_status "Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push backend
print_status "Building backend image..."
cd backend
docker build -t $ECR_REGISTRY/placement-portal-backend:latest .
docker push $ECR_REGISTRY/placement-portal-backend:latest
cd ..

# Build and push frontend
print_status "Building frontend image..."
cd frontend
docker build -t $ECR_REGISTRY/placement-portal-frontend:latest .
docker push $ECR_REGISTRY/placement-portal-frontend:latest
cd ..

print_success "Docker images built and pushed successfully!"

# Step 3: Wait for Auto Scaling Groups to launch instances
print_status "Step 3: Waiting for Auto Scaling Groups to launch instances..."

print_status "Waiting for backend instances to launch..."
while true; do
    backend_count=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-backend-asg \
        --region us-east-1 \
        --query 'AutoScalingGroups[0].Instances | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$backend_count" -gt 0 ]; then
        print_success "Backend instances are launching ($backend_count instances)"
        break
    fi
    
    echo "Waiting for backend instances to launch..."
    sleep 15
done

print_status "Waiting for frontend instances to launch..."
while true; do
    frontend_count=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-frontend-asg \
        --region us-east-1 \
        --query 'AutoScalingGroups[0].Instances | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$frontend_count" -gt 0 ]; then
        print_success "Frontend instances are launching ($frontend_count instances)"
        break
    fi
    
    echo "Waiting for frontend instances to launch..."
    sleep 15
done

# Step 4: Wait for target groups to become healthy
print_status "Step 4: Waiting for target groups to become healthy..."

print_status "Waiting for backend target group to become healthy..."
while true; do
    healthy_count=$(aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups \
            --names placement-portal-backend-tg \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text --region us-east-1) \
        --region us-east-1 \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$healthy_count" -gt 0 ]; then
        print_success "Backend target group is healthy ($healthy_count healthy targets)"
        break
    fi
    
    echo "Waiting for backend targets to become healthy..."
    sleep 30
done

print_status "Waiting for frontend target group to become healthy..."
while true; do
    healthy_count=$(aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups \
            --names placement-portal-frontend-tg \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text --region us-east-1) \
        --region us-east-1 \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$healthy_count" -gt 0 ]; then
        print_success "Frontend target group is healthy ($healthy_count healthy targets)"
        break
    fi
    
    echo "Waiting for frontend targets to become healthy..."
    sleep 30
done

# Step 5: Display deployment summary
print_success "🎉 Initial deployment completed successfully!"

echo ""
echo "=========================================="
echo "           DEPLOYMENT SUMMARY"
echo "=========================================="
echo "Application URL: http://$ALB_DNS"
echo "Backend ECR: $BACKEND_ECR"
echo "Frontend ECR: $FRONTEND_ECR"
echo ""

# Get Jenkins and SonarQube IPs
JENKINS_IP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-jenkins-eip" --query 'Addresses[0].PublicIp' --output text --region us-east-1 2>/dev/null || echo "Not available")
SONARQUBE_IP=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-sonarqube-eip" --query 'Addresses[0].PublicIp' --output text --region us-east-1 2>/dev/null || echo "Not available")

echo "Jenkins URL: http://$JENKINS_IP:8080"
echo "SonarQube URL: http://$SONARQUBE_IP:9000"
echo ""
echo "Next steps:"
echo "  1. Configure Jenkins with GitHub webhook"
echo "  2. Set up SonarQube project"
echo "  3. For future deployments, use: ./deploy-ec2.sh"
echo "=========================================="
