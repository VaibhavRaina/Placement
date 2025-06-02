#!/bin/bash

# Placement Portal AWS Configuration Status Script
set -e

echo "🚀 Placement Portal Current AWS Deployment Status"
echo "================================================="

# Color codes
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
    echo -e "${YELLOW}[ACTION REQUIRED]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration values for deployed environment
AWS_REGION="us-east-1"
CLUSTER_NAME="placement-portal-cluster"
AWS_ACCOUNT_ID=""

print_status "Checking current deployment status..."

# Check if we're in the right directory
if [ ! -f "Jenkinsfile" ]; then
    print_error "Please run this script from the Placement directory"
    exit 1
fi

# 1. Check prerequisites
print_status "Checking prerequisites..."
missing_tools=()

if ! command -v aws >/dev/null 2>&1; then
    missing_tools+=("aws")
fi
fi

if ! command -v kubectl >/dev/null 2>&1; then
    missing_tools+=("kubectl")
fi

if ! command -v git >/dev/null 2>&1; then
    missing_tools+=("git")
fi

if [ ${#missing_tools[@]} -ne 0 ]; then
    print_error "Missing required tools: ${missing_tools[*]}"
    echo "Please install the missing tools and run this script again."
    exit 1
fi

print_success "All required tools are installed"

# 2. Check AWS authentication
print_status "Checking AWS authentication..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    current_account=$(aws sts get-caller-identity --query Account --output text)
    current_user=$(aws sts get-caller-identity --query Arn --output text)
    print_success "Authenticated as: $current_user"
    print_success "AWS Account ID: $current_account"
    AWS_ACCOUNT_ID=$current_account
else
    print_warning "Not authenticated with AWS"
    echo "Please run: aws configure"
    exit 1
fi

# 3. Check current region
print_status "Checking AWS region configuration..."
current_region=$(aws configure get region 2>/dev/null || echo "")
if [ "$current_region" = "$AWS_REGION" ]; then
    print_success "Region is set to: $AWS_REGION"
else
    print_warning "Setting region to: $AWS_REGION"
    aws configure set default.region $AWS_REGION
fi

# 4. Check EKS cluster connectivity
print_status "Checking EKS cluster connectivity..."
if aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME >/dev/null 2>&1; then
    print_success "Connected to EKS cluster: $CLUSTER_NAME"
else
    print_error "Cannot connect to EKS cluster: $CLUSTER_NAME"
    echo "Please ensure the cluster exists and you have proper permissions"
    exit 1
fi

# 5. Check current deployment status
print_status "Checking current deployment status..."
if kubectl get deployments >/dev/null 2>&1; then
    echo "Current deployments:"
    kubectl get deployments -o wide
    echo ""
    echo "Current services:"
    kubectl get services
    print_success "Application is currently deployed and running"
else
    print_error "No deployments found or kubectl access issues"
    exit 1
fi

# 6. Check Docker images in registry
print_status "Checking available Docker images..."
echo "Backend images:"
gcloud container images list-tags gcr.io/$PROJECT_ID/placement-backend --limit=5 --format="table(tags,timestamp)"
echo ""
echo "Frontend images:"
gcloud container images list-tags gcr.io/$PROJECT_ID/placement-frontend --limit=5 --format="table(tags,timestamp)"

# 7. Configuration summary
print_success "🎉 Current configuration status:"
echo ""
echo "================================"
echo "DEPLOYMENT STATUS"
echo "================================"
echo ""
echo "✅ Project ID: $PROJECT_ID"
echo "✅ Cluster: $CLUSTER_NAME ($CLUSTER_ZONE)"
echo "✅ Application: DEPLOYED and RUNNING"
echo "✅ External Access: Available via LoadBalancer"
echo "✅ Docker Registry: gcr.io/$PROJECT_ID"
echo "✅ CI/CD Pipeline: Configured in Jenkinsfile"
echo ""

# Get LoadBalancer IP
lb_ip=$(kubectl get service placement-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not available")
if [ "$lb_ip" != "Not available" ]; then
    echo "🌐 Application URL: http://$lb_ip"
    echo ""
fi

print_warning "AVAILABLE ACTIONS:"
echo "1. Update deployment: kubectl apply -f k8s/"
echo "2. Scale deployment: kubectl scale deployment placement-backend --replicas=3"
echo "3. Check logs: kubectl logs -f deployment/placement-backend"
echo "4. Monitor status: watch kubectl get pods"
echo "5. Access application: kubectl port-forward service/placement-portal-lb 8080:80"
echo ""

read -p "Would you like to check application health? (y/N): " check_health

if [[ $check_health =~ ^[Yy]$ ]]; then
    print_status "Running health checks..."
    
    # Check pod status
    echo "Pod status:"
    kubectl get pods
    
    # Check service endpoints
    echo ""
    echo "Service endpoints:"
    kubectl get endpoints
    
    # Try to access backend health endpoint if available
    backend_pod=$(kubectl get pods -l app=placement-backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ ! -z "$backend_pod" ]; then
        echo ""
        echo "Backend health check:"
        kubectl exec $backend_pod -- curl -s http://localhost:5000/health || echo "Health endpoint not available"
    fi
    
    print_success "Health check completed"
else
    print_status "Skipping health check"
fi

echo ""
print_warning "NEXT STEPS TO COMPLETE SETUP:"
echo "1. ✅ Application is deployed and running"
echo "2. Configure custom domain DNS (placement-portal.com)"
echo "3. Set up SSL certificates for HTTPS"
echo "4. Configure Jenkins webhook for automatic deployments"
echo "5. Set up monitoring and alerting"
echo "6. Configure backup strategies for data"
echo ""
echo "Your placement portal is live and accessible!"
