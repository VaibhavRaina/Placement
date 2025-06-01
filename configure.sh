#!/bin/bash

# Quick Configuration Setup Script
set -e

echo "🚀 Placement Portal CI/CD Configuration Helper"
echo "=============================================="

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

# Check if we're in the right directory
if [ ! -f "deploy-cicd.sh" ]; then
    print_error "Please run this script from the Placement directory"
    exit 1
fi

print_status "Starting configuration setup..."

# 1. Check prerequisites
print_status "Checking prerequisites..."
missing_tools=()

if ! command -v gcloud >/dev/null 2>&1; then
    missing_tools+=("gcloud")
fi

if ! command -v git >/dev/null 2>&1; then
    missing_tools+=("git")
fi

if [ ${#missing_tools[@]} -ne 0 ]; then
    print_error "Missing required tools: ${missing_tools[*]}"
    exit 1
fi

print_success "All prerequisites are installed"

# 2. Prompt for GitHub configuration
print_warning "STEP 1: GitHub Configuration Required"
echo "Please provide your GitHub details:"

read -p "Enter your GitHub username: " github_username
read -p "Enter your repository name [placement-portal]: " github_repo
github_repo=${github_repo:-placement-portal}

# Update terraform.tfvars
print_status "Updating Terraform configuration..."
sed -i "s/github_owner = \"your-github-username\"/github_owner = \"$github_username\"/" infrastructure/terraform.tfvars
sed -i "s/github_repo = \"placement-portal\"/github_repo = \"$github_repo\"/" infrastructure/terraform.tfvars

print_success "Updated infrastructure/terraform.tfvars"

# 3. Check GCP authentication
print_warning "STEP 2: GCP Authentication Check"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
    print_status "Please authenticate with Google Cloud..."
    gcloud auth login
else
    print_success "Already authenticated with GCP"
fi

# Set project
gcloud config set project avid-sunset-435316-a6
print_success "Set GCP project to avid-sunset-435316-a6"

# 4. Generate secure passwords if needed
print_status "Checking for secure passwords in terraform.tfvars..."
if grep -q "PlacementSecure2025!" infrastructure/terraform.tfvars; then
    print_warning "STEP 3: Consider updating default passwords in infrastructure/terraform.tfvars"
    echo "Current passwords are set to defaults. For production, consider changing:"
    echo "- db_password"
    echo "- jenkins_admin_password" 
    echo "- sonarqube_admin_password"
    
    read -p "Would you like to generate secure passwords now? (y/N): " generate_passwords
    if [[ $generate_passwords =~ ^[Yy]$ ]]; then
        new_db_password=$(openssl rand -base64 32)
        new_jenkins_password=$(openssl rand -base64 32)
        new_sonar_password=$(openssl rand -base64 32)
        
        sed -i "s/db_password = \"PlacementSecure2025!\"/db_password = \"$new_db_password\"/" infrastructure/terraform.tfvars
        sed -i "s/jenkins_admin_password = \"JenkinsAdmin2025!\"/jenkins_admin_password = \"$new_jenkins_password\"/" infrastructure/terraform.tfvars
        sed -i "s/sonarqube_admin_password = \"SonarAdmin2025!\"/sonarqube_admin_password = \"$new_sonar_password\"/" infrastructure/terraform.tfvars
        
        print_success "Generated and updated secure passwords"
        echo "💾 IMPORTANT: Save these passwords securely!"
        echo "Database password: $new_db_password"
        echo "Jenkins password: $new_jenkins_password"
        echo "SonarQube password: $new_sonar_password"
        
        read -p "Press Enter to continue..."
    fi
else
    print_success "Custom passwords already configured"
fi

# 5. Validate configurations
print_status "Validating configurations..."

# Check Terraform syntax
cd infrastructure
if terraform validate >/dev/null 2>&1; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration has errors"
    terraform validate
    exit 1
fi
cd ..

# Check if SonarQube config exists
if [ -f "sonar-project.properties" ]; then
    print_success "SonarQube configuration found"
else
    print_error "SonarQube configuration missing"
    exit 1
fi

# 6. Ready to deploy
print_success "🎉 Configuration setup complete!"
echo ""
echo "================================"
echo "READY TO DEPLOY YOUR CI/CD PIPELINE"
echo "================================"
echo ""
echo "Your configuration:"
echo "- Project ID: avid-sunset-435316-a6"
echo "- GitHub User: $github_username"
echo "- GitHub Repo: $github_repo"
echo "- Region: us-central1"
echo "- Zone: us-central1-a"
echo ""
print_warning "NEXT STEPS:"
echo "1. Run the deployment: ./deploy-cicd.sh avid-sunset-435316-a6"
echo "2. Wait for infrastructure to be created (~15-20 minutes)"
echo "3. Follow the post-deployment configuration in CONFIGURATION.md"
echo ""
read -p "Would you like to start the deployment now? (y/N): " start_deployment

if [[ $start_deployment =~ ^[Yy]$ ]]; then
    print_status "Starting deployment..."
    ./deploy-cicd.sh avid-sunset-435316-a6
else
    print_status "Deployment not started. Run './deploy-cicd.sh avid-sunset-435316-a6' when ready."
fi