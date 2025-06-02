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
CLUSTER_NAME="placement-portal-cluster"

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
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl not found. Please install kubectl first.${NC}"
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
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    BACKEND_ECR_URL=$(terraform output -raw backend_repository_url)
    FRONTEND_ECR_URL=$(terraform output -raw frontend_repository_url)
    DOCDB_ENDPOINT=$(terraform output -raw docdb_cluster_endpoint)
    
    cd ..
    
    echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    echo -e "${BLUE}Cluster Name: ${CLUSTER_NAME}${NC}"
    echo -e "${BLUE}Backend ECR: ${BACKEND_ECR_URL}${NC}"
    echo -e "${BLUE}Frontend ECR: ${FRONTEND_ECR_URL}${NC}"
    echo -e "${BLUE}DocumentDB Endpoint: ${DOCDB_ENDPOINT}${NC}"
}

# Configure kubectl for EKS
configure_kubectl() {
    echo -e "${BLUE}Configuring kubectl for EKS...${NC}"
    
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
    
    # Verify connection
    kubectl get nodes
    
    echo -e "${GREEN}✅ kubectl configured for EKS${NC}"
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

# Update Kubernetes manifests
update_k8s_manifests() {
    echo -e "${BLUE}Updating Kubernetes manifests...${NC}"
    
    # Update production deployments
    sed -i "s|__BACKEND_ECR_REPO__:latest|${BACKEND_ECR_URL}:latest|g" k8s/backend-deployment.yaml
    sed -i "s|__FRONTEND_ECR_REPO__:latest|${FRONTEND_ECR_URL}:latest|g" k8s/frontend-deployment.yaml
    
    # Update staging deployments
    sed -i "s|__BACKEND_ECR_REPO__:staging|${BACKEND_ECR_URL}:latest|g" k8s/staging/backend-deployment.yaml
    sed -i "s|__FRONTEND_ECR_REPO__:staging|${FRONTEND_ECR_URL}:latest|g" k8s/staging/frontend-deployment.yaml
    
    # Update DocumentDB connection string in secrets
    MONGODB_URI="mongodb://placement:Placement@123@${DOCDB_ENDPOINT}:27017/placement_db?ssl=true&retryWrites=false"
    MONGODB_URI_B64=$(echo -n "$MONGODB_URI" | base64 -w 0)
    sed -i "s|mongodb-uri: .*|mongodb-uri: ${MONGODB_URI_B64}|g" k8s/secrets.yaml
    
    echo -e "${GREEN}✅ Kubernetes manifests updated${NC}"
}

# Deploy to Kubernetes
deploy_k8s() {
    echo -e "${BLUE}Deploying to Kubernetes...${NC}"
    
    # Apply secrets first
    kubectl apply -f k8s/secrets.yaml
    
    # Apply persistent volumes
    kubectl apply -f k8s/mongodb-pvc.yaml
    
    # Apply MongoDB deployment
    kubectl apply -f k8s/mongodb-deployment.yaml
    kubectl apply -f k8s/mongodb-service.yaml
    
    # Wait for MongoDB to be ready
    echo -e "${YELLOW}Waiting for MongoDB to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s
    
    # Apply application deployments
    kubectl apply -f k8s/backend-deployment.yaml
    kubectl apply -f k8s/backend-service.yaml
    kubectl apply -f k8s/frontend-deployment.yaml
    kubectl apply -f k8s/frontend-service.yaml
    
    # Apply ingress
    kubectl apply -f k8s/ingress.yaml
    
    # Wait for deployments to be ready
    echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
    kubectl rollout status deployment/placement-backend --timeout=300s
    kubectl rollout status deployment/placement-frontend --timeout=300s
    
    echo -e "${GREEN}✅ Applications deployed to Kubernetes${NC}"
}

# Get service information
get_service_info() {
    echo -e "${BLUE}Getting service information...${NC}"
    
    echo -e "${YELLOW}Services:${NC}"
    kubectl get services
    
    echo -e "${YELLOW}Ingress:${NC}"
    kubectl get ingress
    
    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods
    
    # Get load balancer URL
    LB_URL=$(kubectl get ingress placement-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    echo -e "${GREEN}Application URL: http://${LB_URL}${NC}"
}

# Main deployment function
main() {
    echo -e "${GREEN}=== AWS Placement Portal Deployment ===${NC}"
    
    check_dependencies
    configure_aws
    deploy_terraform
    configure_kubectl
    build_and_push_images
    update_k8s_manifests
    deploy_k8s
    get_service_info
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${BLUE}Don't forget to update your DNS records to point to the load balancer${NC}"
}

# Run main function
main "$@"
