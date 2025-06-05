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

# Function to check if EC2 instances exist
check_ec2_instances() {
    print_status "Checking if EC2 instances exist..."

    # Check if backend instance exists
    BACKEND_INSTANCE_ID=$(aws ec2 describe-instances \
        --filters 'Name=tag:Name,Values=placement-portal-backend' 'Name=instance-state-name,Values=running' \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text --region $AWS_REGION 2>/dev/null)

    if [ "$BACKEND_INSTANCE_ID" != "None" ] && [ -n "$BACKEND_INSTANCE_ID" ]; then
        print_success "Backend instance exists: $BACKEND_INSTANCE_ID"
        BACKEND_INSTANCE_EXISTS=true
    else
        print_warning "Backend instance does not exist - will be created by Terraform"
        BACKEND_INSTANCE_EXISTS=false
    fi

    # Check if frontend instance exists
    FRONTEND_INSTANCE_ID=$(aws ec2 describe-instances \
        --filters 'Name=tag:Name,Values=placement-portal-frontend' 'Name=instance-state-name,Values=running' \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text --region $AWS_REGION 2>/dev/null)

    if [ "$FRONTEND_INSTANCE_ID" != "None" ] && [ -n "$FRONTEND_INSTANCE_ID" ]; then
        print_success "Frontend instance exists: $FRONTEND_INSTANCE_ID"
        FRONTEND_INSTANCE_EXISTS=true
    else
        print_warning "Frontend instance does not exist - will be created by Terraform"
        FRONTEND_INSTANCE_EXISTS=false
    fi
}

# Function to trigger direct EC2 deployment
trigger_ec2_deployment() {
    print_status "Triggering EC2 deployment..."

    if [ "$BACKEND_INSTANCE_EXISTS" = true ]; then
        # Deploy to backend instance
        print_status "Deploying to backend instance: $BACKEND_INSTANCE_ID"
        aws ssm send-command \
            --instance-ids $BACKEND_INSTANCE_ID \
            --document-name "AWS-RunShellScript" \
            --parameters '{"commands":["cd /opt/placement-backend","export ECR_REGISTRY='$ECR_REGISTRY'","export IMAGE_TAG='$IMAGE_TAG'","sed -i \"s|image: .*placement-portal-backend:.*|image: '$ECR_REGISTRY'/placement-portal-backend:'$IMAGE_TAG'|g\" docker-compose.yml","./deploy.sh"]}' \
            --region $AWS_REGION
        print_success "Backend deployment command sent"
    else
        print_warning "Skipping backend deployment - instance doesn't exist yet"
    fi

    if [ "$FRONTEND_INSTANCE_EXISTS" = true ]; then
        # Deploy to frontend instance
        print_status "Deploying to frontend instance: $FRONTEND_INSTANCE_ID"
        aws ssm send-command \
            --instance-ids $FRONTEND_INSTANCE_ID \
            --document-name "AWS-RunShellScript" \
            --parameters '{"commands":["cd /opt/placement-frontend","export ECR_REGISTRY='$ECR_REGISTRY'","export IMAGE_TAG='$IMAGE_TAG'","sed -i \"s|image: .*placement-portal-frontend:.*|image: '$ECR_REGISTRY'/placement-portal-frontend:'$IMAGE_TAG'|g\" docker-compose.yml","./deploy.sh"]}' \
            --region $AWS_REGION
        print_success "Frontend deployment command sent"
    else
        print_warning "Skipping frontend deployment - instance doesn't exist yet"
    fi
}

# Function to wait for deployment completion
wait_for_deployment() {
    print_status "Waiting for deployment to complete..."

    # Give time for deployment to start
    sleep 60

    if [ "$BACKEND_INSTANCE_EXISTS" = true ]; then
        # Wait for backend deployment
        print_status "Monitoring backend deployment..."

        # Get backend instance IP
        BACKEND_IP=$(aws ec2 describe-instances \
            --instance-ids $BACKEND_INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text --region $AWS_REGION)

        # Health check loop
        for i in {1..10}; do
            if curl -f -s http://$BACKEND_IP:5000/health > /dev/null; then
                print_success "Backend health check passed"
                break
            else
                echo "Backend health check failed, attempt $i/10"
                if [ $i -eq 10 ]; then
                    print_error "Backend deployment failed - health check timeout"
                    exit 1
                fi
                sleep 30
            fi
        done
    else
        print_warning "Skipping backend deployment monitoring - instance doesn't exist"
    fi

    if [ "$FRONTEND_INSTANCE_EXISTS" = true ]; then
        # Wait for frontend deployment
        print_status "Monitoring frontend deployment..."

        # Get frontend instance IP
        FRONTEND_IP=$(aws ec2 describe-instances \
            --instance-ids $FRONTEND_INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text --region $AWS_REGION)

        # Health check loop
        for i in {1..10}; do
            if curl -f -s http://$FRONTEND_IP > /dev/null; then
                print_success "Frontend health check passed"
                break
            else
                echo "Frontend health check failed, attempt $i/10"
                if [ $i -eq 10 ]; then
                    print_error "Frontend deployment failed - health check timeout"
                    exit 1
                fi
                sleep 30
            fi
        done
    else
        print_warning "Skipping frontend deployment monitoring - instance doesn't exist"
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

    # Get instance status
    BACKEND_STATUS="Not Found"
    FRONTEND_STATUS="Not Found"

    if [ "$BACKEND_INSTANCE_EXISTS" = true ]; then
        BACKEND_STATUS="Running ($BACKEND_INSTANCE_ID)"
    fi

    if [ "$FRONTEND_INSTANCE_EXISTS" = true ]; then
        FRONTEND_STATUS="Running ($FRONTEND_INSTANCE_ID)"
    fi

    echo ""
    echo "=========================================="
    print_success "Deployment completed successfully!"
    echo "=========================================="
    echo "Application URL: http://$LB_DNS"
    echo "Backend instance: $BACKEND_STATUS"
    echo "Frontend instance: $FRONTEND_STATUS"
    echo "Image tag: $IMAGE_TAG"
    echo "=========================================="
}

# Main execution
main() {
    check_aws_config
    ecr_login
    build_and_push_images
    check_launch_templates
    check_ec2_instances
    update_launch_templates
    trigger_ec2_deployment
    wait_for_deployment
    show_deployment_status
}

# Run main function
main "$@"
