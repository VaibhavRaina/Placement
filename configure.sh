#!/bin/bash

# Placement Portal AWS Configuration Update Script
set -e

echo "🚀 Placement Portal AWS CI/CD Configuration Update"
echo "=================================================="

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

if ! command -v kubectl >/dev/null 2>&1; then
    missing_tools+=("kubectl")
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
sed -i "s/aws_region = \"us-east-1\"/aws_region = \"$AWS_REGION\"/" infrastructure/terraform.tfvars

print_success "Updated infrastructure/terraform.tfvars"

# 3. Check AWS authentication
print_warning "STEP 2: AWS Authentication Check"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_status "Please configure AWS credentials..."
    echo "Run: aws configure"
    echo "Enter your AWS Access Key ID, Secret Access Key, and default region"
    exit 1
else
    print_success "Already authenticated with AWS"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "Using AWS Account: $AWS_ACCOUNT_ID"
fi

# Set default region
aws configure set default.region $AWS_REGION
print_success "Set AWS region to $AWS_REGION"

# 4. Generate secure passwords if needed
print_status "Checking for secure passwords in terraform.tfvars..."
if grep -q "PlacementSecure2025!" infrastructure/terraform.tfvars; then
    print_warning "STEP 3: Consider updating default passwords in infrastructure/terraform.tfvars"
    echo "Current passwords are set to defaults. For production, consider changing:"
    echo "- docdb_password"
    echo "- jenkins_admin_password" 
    echo "- sonarqube_admin_password"
    
    read -p "Would you like to generate secure passwords now? (y/N): " generate_passwords
    if [[ $generate_passwords =~ ^[Yy]$ ]]; then
        new_db_password=$(openssl rand -base64 32)
        new_jenkins_password=$(openssl rand -base64 32)
        new_sonar_password=$(openssl rand -base64 32)
        
        sed -i "s/docdb_password = \"PlacementSecure2025!\"/docdb_password = \"$new_db_password\"/" infrastructure/terraform.tfvars
        sed -i "s/jenkins_admin_password = \"JenkinsAdmin2025!\"/jenkins_admin_password = \"$new_jenkins_password\"/" infrastructure/terraform.tfvars
        sed -i "s/sonarqube_admin_password = \"SonarAdmin2025!\"/sonarqube_admin_password = \"$new_sonar_password\"/" infrastructure/terraform.tfvars
        
        print_success "Generated and updated secure passwords"
        echo "💾 IMPORTANT: Save these passwords securely!"
        echo "DocumentDB password: $new_db_password"
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
echo "- AWS Account ID: $AWS_ACCOUNT_ID"
echo "- GitHub User: $github_username"
echo "- GitHub Repo: $github_repo"
echo "- AWS Region: $AWS_REGION"
echo "- EKS Cluster: $CLUSTER_NAME"
echo ""
print_warning "NEXT STEPS:"
echo "1. Run the deployment: ./deploy-aws.sh"
echo "2. Wait for infrastructure to be created (~15-20 minutes)"
echo "3. Follow the post-deployment configuration in AWS_MIGRATION_README.md"
echo ""
read -p "Would you like to start the deployment now? (y/N): " start_deployment

if [[ $start_deployment =~ ^[Yy]$ ]]; then
    print_status "Starting deployment..."
    ./deploy-aws.sh
else
    print_status "Deployment not started. Run './deploy-aws.sh' when ready."
fi