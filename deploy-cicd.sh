#!/bin/bash

# Complete CI/CD Pipeline Deployment Script
set -e

echo "🚀 Starting Complete CI/CD Pipeline Deployment for Placement Portal"

# Configuration Variables
PROJECT_ID=${1:-"your-gcp-project-id"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}
CLUSTER_NAME="placement-portal-cluster"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists gcloud; then
        missing_tools+=("gcloud")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists helm; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Setup GCP authentication and project
setup_gcp() {
    print_status "Setting up GCP authentication and project..."
    
    # Check if already authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
        print_status "Please authenticate with GCP..."
        gcloud auth login
    fi
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Enable required APIs
    print_status "Enabling required GCP APIs..."
    gcloud services enable \
        container.googleapis.com \
        compute.googleapis.com \
        cloudbuild.googleapis.com \
        containerregistry.googleapis.com \
        sqladmin.googleapis.com \
        cloudresourcemanager.googleapis.com \
        servicenetworking.googleapis.com
    
    print_success "GCP setup completed"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd infrastructure
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f terraform.tfvars ]; then
        cat > terraform.tfvars << EOF
project_id = "$PROJECT_ID"
region = "$REGION"
zone = "$ZONE"
cluster_name = "$CLUSTER_NAME"
gke_num_nodes = 2
db_username = "placement_user"
db_password = "$(openssl rand -base64 32)"
github_owner = "your-github-username"
github_repo = "placement-portal"
jenkins_admin_password = "$(openssl rand -base64 32)"
sonarqube_admin_password = "$(openssl rand -base64 32)"
EOF
        print_warning "Created terraform.tfvars with default values. Please update with your actual values."
    fi
    
    # Plan and apply
    terraform plan
    terraform apply -auto-approve
    
    # Get outputs
    JENKINS_IP=$(terraform output -raw jenkins_ip)
    SONARQUBE_IP=$(terraform output -raw sonarqube_ip)
    GKE_CLUSTER_NAME=$(terraform output -raw gke_cluster_name)
    
    print_success "Infrastructure deployed successfully"
    print_status "Jenkins URL: http://$JENKINS_IP:8080"
    print_status "SonarQube URL: http://$SONARQUBE_IP:9000"
    
    cd ..
}

# Configure kubectl for GKE
configure_kubectl() {
    print_status "Configuring kubectl for GKE cluster..."
    
    gcloud container clusters get-credentials $GKE_CLUSTER_NAME \
        --zone $ZONE \
        --project $PROJECT_ID
    
    print_success "kubectl configured for GKE cluster"
}

# Deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set grafana.adminPassword=admin123 \
        --set grafana.service.type=LoadBalancer \
        --set prometheus.service.type=LoadBalancer
    
    print_success "Monitoring stack deployed"
}

# Build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    # Configure Docker for GCR
    gcloud auth configure-docker
    
    # Build backend image
    print_status "Building backend image..."
    cd backend
    docker build -t gcr.io/$PROJECT_ID/placement-backend:latest .
    docker push gcr.io/$PROJECT_ID/placement-backend:latest
    cd ..
    
    # Build frontend image
    print_status "Building frontend image..."
    cd frontend
    docker build -t gcr.io/$PROJECT_ID/placement-frontend:latest .
    docker push gcr.io/$PROJECT_ID/placement-frontend:latest
    cd ..
    
    print_success "Docker images built and pushed"
}

# Deploy applications to Kubernetes
deploy_applications() {
    print_status "Deploying applications to Kubernetes..."
    
    # Update image tags in deployment files
    sed -i "s|PROJECT_ID|$PROJECT_ID|g" k8s/*.yaml
    sed -i "s|IMAGE_TAG|latest|g" k8s/*.yaml
    
    # Apply Kubernetes configurations
    kubectl apply -f k8s/secrets.yaml
    kubectl apply -f k8s/backend-deployment.yaml
    kubectl apply -f k8s/frontend-deployment.yaml
    kubectl apply -f k8s/backend-service.yaml
    kubectl apply -f k8s/frontend-service.yaml
    kubectl apply -f k8s/ingress.yaml
    kubectl apply -f k8s/autoscaling.yaml
    
    print_success "Applications deployed to Kubernetes"
}

# Setup Jenkins pipeline
setup_jenkins() {
    print_status "Setting up Jenkins pipeline..."
    
    print_status "Waiting for Jenkins to be ready..."
    sleep 120
    
    # Get Jenkins initial admin password
    JENKINS_PASSWORD=$(gcloud compute ssh jenkins-server --zone=$ZONE --command="sudo cat /var/lib/jenkins/secrets/initialAdminPassword" --quiet)
    
    print_success "Jenkins setup completed"
    print_status "Jenkins URL: http://$JENKINS_IP:8080"
    print_status "Initial Admin Password: $JENKINS_PASSWORD"
    print_warning "Please complete Jenkins setup manually through the web interface"
}

# Main deployment function
main() {
    print_status "Starting deployment with the following configuration:"
    print_status "Project ID: $PROJECT_ID"
    print_status "Region: $REGION"
    print_status "Zone: $ZONE"
    print_status "Cluster Name: $CLUSTER_NAME"
    
    read -p "Do you want to continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    
    check_prerequisites
    setup_gcp
    deploy_infrastructure
    configure_kubectl
    deploy_monitoring
    build_and_push_images
    deploy_applications
    setup_jenkins
    
    print_success "🎉 Complete CI/CD Pipeline deployment finished!"
    print_status "Next steps:"
    print_status "1. Complete Jenkins setup at: http://$JENKINS_IP:8080"
    print_status "2. Configure SonarQube at: http://$SONARQUBE_IP:9000"
    print_status "3. Set up your Git repository and webhook"
    print_status "4. Configure domain DNS to point to the load balancer IP"
    print_status "5. Test the complete pipeline by pushing code changes"
}

# Run main function
main "$@"