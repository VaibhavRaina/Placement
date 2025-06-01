#!/bin/bash

# GCP Deployment Script for Placement Portal
set -e

# Variables
PROJECT_ID="avid-sunset-435316-a6"
REGION="us-central1"
CLUSTER_NAME="placement-cluster"

echo "🚀 Starting GCP deployment for Placement Portal..."

# Step 1: Authenticate with GCP
echo "📋 Step 1: Authenticating with GCP..."
gcloud auth login
gcloud config set project $PROJECT_ID

# Step 2: Enable required APIs
echo "📋 Step 2: Enabling required GCP APIs..."
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Step 3: Create GCS bucket for Terraform state
echo "📋 Step 3: Creating GCS bucket for Terraform state..."
BUCKET_NAME="${PROJECT_ID}-terraform-state"
gsutil mb gs://${BUCKET_NAME} || echo "Bucket already exists"
gsutil versioning set on gs://${BUCKET_NAME}

# Step 4: Deploy infrastructure with Terraform
echo "📋 Step 4: Deploying infrastructure with Terraform..."
cd infrastructure
terraform init -backend-config="bucket=${BUCKET_NAME}"
terraform plan -var="project_id=${PROJECT_ID}" -var="db_password=${DB_PASSWORD:-defaultpass123}"
terraform apply -var="project_id=${PROJECT_ID}" -var="db_password=${DB_PASSWORD:-defaultpass123}" -auto-approve

# Step 5: Get GKE credentials
echo "📋 Step 5: Getting GKE cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

# Step 6: Create Kubernetes secrets
echo "📋 Step 6: Creating Kubernetes secrets..."
cd ../k8s

# Get database IP from Terraform output
DB_IP=$(cd ../infrastructure && terraform output -raw database_ip)
DB_USER="placement_user"
DB_PASSWORD=${DB_PASSWORD:-defaultpass123}
JWT_SECRET=${JWT_SECRET:-your-super-secret-jwt-key-here}

# Create secrets with base64 encoding
kubectl create secret generic db-secret \
  --from-literal=host=$DB_IP \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-secret \
  --from-literal=jwt-secret=$JWT_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Infrastructure deployed successfully!"
echo "📝 Next steps:"
echo "   1. Update Docker images in Jenkins pipeline"
echo "   2. Configure your domain DNS to point to the LoadBalancer IP"
echo "   3. Update the domain in k8s/ingress.yaml"
echo "   4. Run the Jenkins pipeline to deploy the application"