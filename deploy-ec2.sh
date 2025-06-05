#!/bin/bash

# EC2 Deployment Script for Placement Portal
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

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
IMAGE_TAG=${IMAGE_TAG:-latest}

echo -e "${GREEN}🚀 Starting EC2 Deployment for Placement Portal${NC}"
echo "========================================================"

# Function to check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI not configured. Please run 'aws configure'"
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS Account ID: $AWS_ACCOUNT_ID"
}

# Function to get ECR login
ecr_login() {
    print_status "Logging into ECR..."
    
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    print_success "ECR login successful"
}

# Function to build and push images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    # Build backend image
    print_status "Building backend image..."
    cd backend
    docker build -t $ECR_REGISTRY/placement-portal-backend:$IMAGE_TAG .
    docker push $ECR_REGISTRY/placement-portal-backend:$IMAGE_TAG
    cd ..
    
    # Build frontend image
    print_status "Building frontend image..."
    cd frontend
    docker build -t $ECR_REGISTRY/placement-portal-frontend:$IMAGE_TAG .
    docker push $ECR_REGISTRY/placement-portal-frontend:$IMAGE_TAG
    cd ..
    
    print_success "Docker images built and pushed successfully"
}

# Function to check if launch templates exist
check_launch_templates() {
    print_status "Checking if launch templates exist..."

    # Check if backend launch template exists
    if aws ec2 describe-launch-templates --launch-template-names placement-portal-backend --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Backend launch template exists"
        BACKEND_LT_EXISTS=true
    else
        print_warning "Backend launch template does not exist - will be created by Terraform"
        BACKEND_LT_EXISTS=false
    fi

    # Check if frontend launch template exists
    if aws ec2 describe-launch-templates --launch-template-names placement-portal-frontend --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Frontend launch template exists"
        FRONTEND_LT_EXISTS=true
    else
        print_warning "Frontend launch template does not exist - will be created by Terraform"
        FRONTEND_LT_EXISTS=false
    fi
}

# Function to update launch templates (only if they exist)
update_launch_templates() {
    print_status "Updating launch templates with new image tags..."

    if [ "$BACKEND_LT_EXISTS" = true ]; then
        # Update backend launch template
        print_status "Updating backend launch template..."
        aws ec2 create-launch-template-version \
            --launch-template-name placement-portal-backend \
            --source-version '$Latest' \
            --launch-template-data "{
                \"UserData\": \"$(echo "#!/bin/bash
cd /opt/placement-backend
export ECR_REGISTRY=$ECR_REGISTRY
export IMAGE_TAG=$IMAGE_TAG
./deploy.sh" | base64 -w 0)\"
            }" \
            --region $AWS_REGION
        print_success "Backend launch template updated"
    else
        print_warning "Skipping backend launch template update - template doesn't exist yet"
    fi

    if [ "$FRONTEND_LT_EXISTS" = true ]; then
        # Update frontend launch template
        print_status "Updating frontend launch template..."
        aws ec2 create-launch-template-version \
            --launch-template-name placement-portal-frontend \
            --source-version '$Latest' \
            --launch-template-data "{
                \"UserData\": \"$(echo "#!/bin/bash
cd /opt/placement-frontend
export ECR_REGISTRY=$ECR_REGISTRY
export IMAGE_TAG=$IMAGE_TAG
./deploy.sh" | base64 -w 0)\"
            }" \
            --region $AWS_REGION
        print_success "Frontend launch template updated"
    else
        print_warning "Skipping frontend launch template update - template doesn't exist yet"
    fi
}

# Function to check if ASGs exist
check_auto_scaling_groups() {
    print_status "Checking if Auto Scaling Groups exist..."

    # Check if backend ASG exists
    if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names placement-portal-backend-asg --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Backend ASG exists"
        BACKEND_ASG_EXISTS=true
    else
        print_warning "Backend ASG does not exist - will be created by Terraform"
        BACKEND_ASG_EXISTS=false
    fi

    # Check if frontend ASG exists
    if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names placement-portal-frontend-asg --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Frontend ASG exists"
        FRONTEND_ASG_EXISTS=true
    else
        print_warning "Frontend ASG does not exist - will be created by Terraform"
        FRONTEND_ASG_EXISTS=false
    fi
}

# Function to trigger rolling deployment (only if ASGs exist)
trigger_rolling_deployment() {
    print_status "Triggering rolling deployment..."

    if [ "$BACKEND_ASG_EXISTS" = true ] && [ "$BACKEND_LT_EXISTS" = true ]; then
        # Start instance refresh for backend ASG
        print_status "Starting backend instance refresh..."
        aws autoscaling start-instance-refresh \
            --auto-scaling-group-name placement-portal-backend-asg \
            --preferences MinHealthyPercentage=50,InstanceWarmup=300 \
            --region $AWS_REGION
        print_success "Backend instance refresh initiated"
    else
        print_warning "Skipping backend deployment - ASG or launch template doesn't exist yet"
    fi

    if [ "$FRONTEND_ASG_EXISTS" = true ] && [ "$FRONTEND_LT_EXISTS" = true ]; then
        # Start instance refresh for frontend ASG
        print_status "Starting frontend instance refresh..."
        aws autoscaling start-instance-refresh \
            --auto-scaling-group-name placement-portal-frontend-asg \
            --preferences MinHealthyPercentage=50,InstanceWarmup=300 \
            --region $AWS_REGION
        print_success "Frontend instance refresh initiated"
    else
        print_warning "Skipping frontend deployment - ASG or launch template doesn't exist yet"
    fi
}

# Function to wait for deployment completion
wait_for_deployment() {
    print_status "Waiting for deployment to complete..."

    if [ "$BACKEND_ASG_EXISTS" = true ] && [ "$BACKEND_LT_EXISTS" = true ]; then
        # Wait for backend deployment
        print_status "Monitoring backend deployment..."
        while true; do
            status=$(aws autoscaling describe-instance-refreshes \
                --auto-scaling-group-name placement-portal-backend-asg \
                --region $AWS_REGION \
                --query 'InstanceRefreshes[0].Status' \
                --output text 2>/dev/null)

            if [ "$status" = "None" ] || [ -z "$status" ]; then
                print_warning "No active backend instance refresh found"
                break
            fi

            echo "Backend refresh status: $status"

            if [ "$status" = "Successful" ]; then
                print_success "Backend deployment completed successfully"
                break
            elif [ "$status" = "Failed" ] || [ "$status" = "Cancelled" ]; then
                print_error "Backend deployment failed with status: $status"
                exit 1
            fi

            sleep 30
        done
    else
        print_warning "Skipping backend deployment monitoring - ASG or launch template doesn't exist"
    fi

    if [ "$FRONTEND_ASG_EXISTS" = true ] && [ "$FRONTEND_LT_EXISTS" = true ]; then
        # Wait for frontend deployment
        print_status "Monitoring frontend deployment..."
        while true; do
            status=$(aws autoscaling describe-instance-refreshes \
                --auto-scaling-group-name placement-portal-frontend-asg \
                --region $AWS_REGION \
                --query 'InstanceRefreshes[0].Status' \
                --output text 2>/dev/null)

            if [ "$status" = "None" ] || [ -z "$status" ]; then
                print_warning "No active frontend instance refresh found"
                break
            fi

            echo "Frontend refresh status: $status"

            if [ "$status" = "Successful" ]; then
                print_success "Frontend deployment completed successfully"
                break
            elif [ "$status" = "Failed" ] || [ "$status" = "Cancelled" ]; then
                print_error "Frontend deployment failed with status: $status"
                exit 1
            fi

            sleep 30
        done
    else
        print_warning "Skipping frontend deployment monitoring - ASG or launch template doesn't exist"
    fi
}

# Function to show deployment status
show_deployment_status() {
    print_status "Deployment Status:"
    
    # Get load balancer DNS
    LB_DNS=$(aws elbv2 describe-load-balancers \
        --names placement-portal-alb \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    # Get ASG instance counts
    BACKEND_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-backend-asg \
        --region $AWS_REGION \
        --query 'AutoScalingGroups[0].Instances | length(@)')
    
    FRONTEND_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-frontend-asg \
        --region $AWS_REGION \
        --query 'AutoScalingGroups[0].Instances | length(@)')
    
    echo ""
    echo "=========================================="
    print_success "Deployment completed successfully!"
    echo "=========================================="
    echo "Application URL: http://$LB_DNS"
    echo "Backend instances: $BACKEND_INSTANCES"
    echo "Frontend instances: $FRONTEND_INSTANCES"
    echo "Image tag: $IMAGE_TAG"
    echo "=========================================="
}

# Main execution
main() {
    check_aws_config
    ecr_login
    build_and_push_images
    check_launch_templates
    check_auto_scaling_groups
    update_launch_templates
    trigger_rolling_deployment
    wait_for_deployment
    show_deployment_status
}

# Run main function
main "$@"
