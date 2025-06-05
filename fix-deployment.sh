#!/bin/bash

# Fix Deployment Script - Troubleshoot and fix bad gateway issues
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

echo -e "${GREEN}🔧 Deployment Fix Script${NC}"
echo "================================"

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Function to check infrastructure status
check_infrastructure() {
    print_status "Checking infrastructure status..."
    
    # Check ASGs
    print_status "Auto Scaling Groups:"
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-backend-asg placement-portal-frontend-asg \
        --query 'AutoScalingGroups[*].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Running:Instances[?LifecycleState==`InService`]|length(@),Total:Instances|length(@)}' \
        --output table 2>/dev/null || print_error "ASGs not found"
    
    # Check Target Groups
    print_status "Target Group Health:"
    
    # Backend TG
    echo "Backend Target Group:"
    aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups --names placement-portal-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null) \
        --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State,Description:TargetHealth.Description}' \
        --output table 2>/dev/null || print_error "Backend target group not found"
    
    # Frontend TG
    echo "Frontend Target Group:"
    aws elbv2 describe-target-health \
        --target-group-arn $(aws elbv2 describe-target-groups --names placement-portal-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null) \
        --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State,Description:TargetHealth.Description}' \
        --output table 2>/dev/null || print_error "Frontend target group not found"
}

# Function to check if images exist in ECR
check_ecr_images() {
    print_status "Checking ECR images..."
    
    # Check backend image
    if aws ecr describe-images --repository-name placement-portal-backend --image-ids imageTag=latest --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Backend image exists in ECR"
    else
        print_error "Backend image not found in ECR"
        return 1
    fi
    
    # Check frontend image
    if aws ecr describe-images --repository-name placement-portal-frontend --image-ids imageTag=latest --region $AWS_REGION >/dev/null 2>&1; then
        print_success "Frontend image exists in ECR"
    else
        print_error "Frontend image not found in ECR"
        return 1
    fi
}

# Function to rebuild and push images
rebuild_images() {
    print_status "Rebuilding and pushing Docker images..."
    
    # ECR login
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
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
    
    print_success "Images rebuilt and pushed successfully"
}

# Function to restart instances
restart_instances() {
    print_status "Restarting instances to pick up new images..."
    
    # Get instance IDs
    BACKEND_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-backend-asg \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text 2>/dev/null)
    
    FRONTEND_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names placement-portal-frontend-asg \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text 2>/dev/null)
    
    if [ -n "$BACKEND_INSTANCES" ]; then
        print_status "Terminating backend instances for refresh..."
        for instance in $BACKEND_INSTANCES; do
            aws ec2 terminate-instances --instance-ids $instance
        done
    fi
    
    if [ -n "$FRONTEND_INSTANCES" ]; then
        print_status "Terminating frontend instances for refresh..."
        for instance in $FRONTEND_INSTANCES; do
            aws ec2 terminate-instances --instance-ids $instance
        done
    fi
    
    print_status "Waiting for new instances to launch..."
    sleep 60
}

# Function to wait for healthy targets
wait_for_healthy_targets() {
    print_status "Waiting for target groups to become healthy..."
    
    # Wait for backend targets
    print_status "Waiting for backend targets..."
    for i in {1..20}; do
        healthy_count=$(aws elbv2 describe-target-health \
            --target-group-arn $(aws elbv2 describe-target-groups --names placement-portal-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null) \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$healthy_count" -gt 0 ]; then
            print_success "Backend targets are healthy ($healthy_count healthy)"
            break
        fi
        
        echo "Attempt $i/20: Waiting for backend targets to become healthy..."
        sleep 30
    done
    
    # Wait for frontend targets
    print_status "Waiting for frontend targets..."
    for i in {1..20}; do
        healthy_count=$(aws elbv2 describe-target-health \
            --target-group-arn $(aws elbv2 describe-target-groups --names placement-portal-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null) \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$healthy_count" -gt 0 ]; then
            print_success "Frontend targets are healthy ($healthy_count healthy)"
            break
        fi
        
        echo "Attempt $i/20: Waiting for frontend targets to become healthy..."
        sleep 30
    done
}

# Function to test application
test_application() {
    print_status "Testing application..."
    
    ALB_DNS=$(aws elbv2 describe-load-balancers --names placement-portal-alb --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null)
    
    if [ -n "$ALB_DNS" ]; then
        print_status "Testing frontend..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/" | grep -q "200\|301\|302"; then
            print_success "Frontend is responding"
        else
            print_warning "Frontend not responding properly"
        fi
        
        print_status "Testing backend API..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/api/health" | grep -q "200"; then
            print_success "Backend API is responding"
        else
            print_warning "Backend API not responding properly"
        fi
        
        echo ""
        print_success "Application URL: http://$ALB_DNS"
    else
        print_error "Could not get load balancer DNS"
    fi
}

# Main execution
main() {
    check_infrastructure
    
    if ! check_ecr_images; then
        print_warning "ECR images missing or outdated. Rebuilding..."
        rebuild_images
    fi
    
    restart_instances
    wait_for_healthy_targets
    test_application
    
    print_success "🎉 Deployment fix completed!"
}

# Run main function
main "$@"
