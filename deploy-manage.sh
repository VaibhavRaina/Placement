#!/bin/bash

# Placement Portal Deployment Management Script
set -e

echo "🚀 Placement Portal Deployment Management"
echo "========================================"

# Configuration Variables
PROJECT_ID="avid-sunset-435316-a6"
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="placement-portal-cluster"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status          - Show current deployment status"
    echo "  deploy          - Deploy/update application"
    echo "  rollback        - Rollback to previous version"
    echo "  scale [N]       - Scale application to N replicas"
    echo "  logs [backend|frontend] - Show application logs"
    echo "  shell [backend|frontend] - Get shell access to pod"
    echo "  build [tag]     - Build and push new Docker images"
    echo "  clean           - Clean up unused resources"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Show current status"
    echo "  $0 deploy                    # Deploy latest changes"
    echo "  $0 scale 3                   # Scale to 3 replicas"
    echo "  $0 logs backend              # Show backend logs"
    echo "  $0 build v1.2.0              # Build with specific tag"
}

# Function to check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v gcloud >/dev/null 2>&1; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Ensure we're connected to the right cluster
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID >/dev/null 2>&1
}

# Function to show deployment status
show_status() {
    print_status "Current deployment status:"
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -o wide
    echo ""
    
    echo "Pods:"
    kubectl get pods -o wide
    echo ""
    
    echo "Services:"
    kubectl get services
    echo ""
    
    # Get LoadBalancer IP
    lb_ip=$(kubectl get service placement-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not available")
    if [ "$lb_ip" != "Not available" ]; then
        echo "🌐 Application URL: http://$lb_ip"
    else
        echo "🌐 LoadBalancer IP: Not available yet"
    fi
    
    echo ""
    echo "Recent Docker images:"
    echo "Backend:"
    gcloud container images list-tags gcr.io/$PROJECT_ID/placement-backend --limit=3 --format="table(tags,timestamp)"
    echo ""
    echo "Frontend:"
    gcloud container images list-tags gcr.io/$PROJECT_ID/placement-frontend --limit=3 --format="table(tags,timestamp)"
}

# Function to deploy application
deploy_app() {
    print_status "Deploying application to GKE cluster..."
    
    # Apply all Kubernetes configurations
    kubectl apply -f k8s/secrets.yaml
    kubectl apply -f k8s/mongodb-deployment.yaml
    kubectl apply -f k8s/mongodb-service.yaml
    kubectl apply -f k8s/backend-deployment.yaml
    kubectl apply -f k8s/backend-service.yaml
    kubectl apply -f k8s/frontend-deployment.yaml
    kubectl apply -f k8s/frontend-service.yaml
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl rollout status deployment/placement-backend --timeout=300s
    kubectl rollout status deployment/placement-frontend --timeout=300s
    
    print_success "Deployment completed successfully!"
    show_status
}

# Function to rollback deployment
rollback_deployment() {
    local component=$1
    
    if [ -z "$component" ]; then
        echo "Available components to rollback:"
        echo "  backend"
        echo "  frontend"
        echo "  all"
        read -p "Which component to rollback? " component
    fi
    
    case $component in
        backend)
            kubectl rollout undo deployment/placement-backend
            kubectl rollout status deployment/placement-backend
            ;;
        frontend)
            kubectl rollout undo deployment/placement-frontend
            kubectl rollout status deployment/placement-frontend
            ;;
        all)
            kubectl rollout undo deployment/placement-backend
            kubectl rollout undo deployment/placement-frontend
            kubectl rollout status deployment/placement-backend
            kubectl rollout status deployment/placement-frontend
            ;;
        *)
            print_error "Invalid component: $component"
            exit 1
            ;;
    esac
    
    print_success "Rollback completed!"
}

# Function to scale deployment
scale_deployment() {
    local replicas=$1
    
    if [ -z "$replicas" ]; then
        read -p "Number of replicas: " replicas
    fi
    
    if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
        print_error "Invalid number of replicas: $replicas"
        exit 1
    fi
    
    print_status "Scaling deployments to $replicas replicas..."
    kubectl scale deployment placement-backend --replicas=$replicas
    kubectl scale deployment placement-frontend --replicas=$replicas
    
    print_status "Waiting for scaling to complete..."
    kubectl rollout status deployment/placement-backend
    kubectl rollout status deployment/placement-frontend
    
    print_success "Scaling completed!"
}

# Function to show logs
show_logs() {
    local component=$1
    local follow=${2:-false}
    
    if [ -z "$component" ]; then
        echo "Available components:"
        echo "  backend"
        echo "  frontend"
        read -p "Which component logs to show? " component
    fi
    
    case $component in
        backend)
            if [ "$follow" = "true" ]; then
                kubectl logs -f deployment/placement-backend
            else
                kubectl logs deployment/placement-backend --tail=50
            fi
            ;;
        frontend)
            if [ "$follow" = "true" ]; then
                kubectl logs -f deployment/placement-frontend
            else
                kubectl logs deployment/placement-frontend --tail=50
            fi
            ;;
        *)
            print_error "Invalid component: $component"
            exit 1
            ;;
    esac
}

# Function to get shell access
get_shell() {
    local component=$1
    
    if [ -z "$component" ]; then
        echo "Available components:"
        echo "  backend"
        echo "  frontend"
        read -p "Which component to access? " component
    fi
    
    local pod_name=""
    case $component in
        backend)
            pod_name=$(kubectl get pods -l app=placement-backend -o jsonpath='{.items[0].metadata.name}')
            ;;
        frontend)
            pod_name=$(kubectl get pods -l app=placement-frontend -o jsonpath='{.items[0].metadata.name}')
            ;;
        *)
            print_error "Invalid component: $component"
            exit 1
            ;;
    esac
    
    if [ -z "$pod_name" ]; then
        print_error "No running pods found for $component"
        exit 1
    fi
    
    print_status "Connecting to pod: $pod_name"
    kubectl exec -it $pod_name -- /bin/sh
}

# Function to build and push images
build_and_push() {
    local tag=${1:-$(date +%Y%m%d-%H%M%S)}
    
    print_status "Building and pushing Docker images with tag: $tag"
    
    # Build backend
    print_status "Building backend image..."
    cd backend
    docker build -t gcr.io/$PROJECT_ID/placement-backend:$tag .
    docker tag gcr.io/$PROJECT_ID/placement-backend:$tag gcr.io/$PROJECT_ID/placement-backend:latest
    
    # Build frontend
    print_status "Building frontend image..."
    cd ../frontend
    docker build -t gcr.io/$PROJECT_ID/placement-frontend:$tag .
    docker tag gcr.io/$PROJECT_ID/placement-frontend:$tag gcr.io/$PROJECT_ID/placement-frontend:latest
    
    # Configure Docker for GCR
    gcloud auth configure-docker --quiet
    
    # Push images
    print_status "Pushing images to GCR..."
    docker push gcr.io/$PROJECT_ID/placement-backend:$tag
    docker push gcr.io/$PROJECT_ID/placement-backend:latest
    docker push gcr.io/$PROJECT_ID/placement-frontend:$tag
    docker push gcr.io/$PROJECT_ID/placement-frontend:latest
    
    cd ..
    print_success "Images built and pushed successfully!"
    
    # Update deployment files
    print_status "Updating deployment files with new image tags..."
    sed -i "s|gcr.io/$PROJECT_ID/placement-backend:.*|gcr.io/$PROJECT_ID/placement-backend:$tag|g" k8s/backend-deployment.yaml
    sed -i "s|gcr.io/$PROJECT_ID/placement-frontend:.*|gcr.io/$PROJECT_ID/placement-frontend:$tag|g" k8s/frontend-deployment.yaml
    
    read -p "Deploy the new images now? (y/N): " deploy_now
    if [[ $deploy_now =~ ^[Yy]$ ]]; then
        deploy_app
    fi
}

# Function to clean up resources
cleanup_resources() {
    print_warning "This will delete unused Docker images and clean up resources"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_status "Cleaning up old Docker images..."
        
        # Keep only latest 5 images for each component
        gcloud container images list-tags gcr.io/$PROJECT_ID/placement-backend --limit=999 --sort-by=TIMESTAMP --format="value(digest)" | tail -n +6 | xargs -I {} gcloud container images delete gcr.io/$PROJECT_ID/placement-backend@{} --force-delete-tags --quiet || true
        
        gcloud container images list-tags gcr.io/$PROJECT_ID/placement-frontend --limit=999 --sort-by=TIMESTAMP --format="value(digest)" | tail -n +6 | xargs -I {} gcloud container images delete gcr.io/$PROJECT_ID/placement-frontend@{} --force-delete-tags --quiet || true
        
        print_success "Cleanup completed!"
    else
        print_status "Cleanup cancelled"
    fi
}

# Main script logic
case "${1:-status}" in
    status)
        check_prerequisites
        show_status
        ;;
    deploy)
        check_prerequisites
        deploy_app
        ;;
    rollback)
        check_prerequisites
        rollback_deployment $2
        ;;
    scale)
        check_prerequisites
        scale_deployment $2
        ;;
    logs)
        check_prerequisites
        show_logs $2 $3
        ;;
    shell)
        check_prerequisites
        get_shell $2
        ;;
    build)
        check_prerequisites
        build_and_push $2
        ;;
    clean)
        check_prerequisites
        cleanup_resources
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
