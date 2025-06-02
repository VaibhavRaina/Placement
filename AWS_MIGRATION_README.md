# AWS Migration Guide - Placement Portal

This document outlines the complete migration of the Placement Portal from Google Cloud Platform (GCP) to Amazon Web Services (AWS).

## 🚀 Migration Overview

### What Changed
- **Container Orchestration**: GKE → EKS (Elastic Kubernetes Service)
- **Container Registry**: GCR → ECR (Elastic Container Registry)
- **Database**: Cloud SQL PostgreSQL → DocumentDB (MongoDB-compatible)
- **Load Balancing**: GCP Load Balancer → AWS Application Load Balancer
- **Compute**: GCE → EC2 instances
- **CLI Tools**: Google Cloud SDK → AWS CLI
- **Authentication**: gcloud service accounts → AWS IAM roles

### Infrastructure Components
- **EKS Cluster** with managed node groups
- **ECR Repositories** for backend and frontend images
- **DocumentDB Cluster** for MongoDB-compatible database
- **Application Load Balancer** for ingress traffic
- **VPC** with public/private subnets and NAT gateways
- **EC2 Instances** for Jenkins and SonarQube
- **IAM Roles and Policies** for secure access

## 📋 Prerequisites

### Required Tools
```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region, and Output format

# Verify configuration
aws sts get-caller-identity
```

## 🏗️ Infrastructure Setup

### 1. Update Terraform Variables
Edit `infrastructure/terraform.tfvars`:
```hcl
aws_region         = "us-east-1"
vpc_cidr          = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
eks_version       = "1.28"
node_instance_type = "t3.medium"
node_desired_size  = 2
node_max_size     = 5
node_min_size     = 1
```

### 2. Deploy Infrastructure
```bash
# Run the automated deployment script
./deploy-aws.sh
```

Or deploy manually:
```bash
# Deploy Terraform infrastructure
cd infrastructure
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name placement-portal-cluster

# Build and push images
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# Backend image
cd backend
docker build -t <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-backend:latest .
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-backend:latest

# Frontend image
cd frontend
docker build -t <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-frontend:latest .
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-frontend:latest

# Deploy to Kubernetes
kubectl apply -f k8s/
```

## 🔧 Configuration Changes

### Environment Variables (Jenkins)
```bash
# Old GCP variables (removed)
PROJECT_ID=avid-sunset-435316-a6
CLUSTER_ZONE=us-central1-a
GCR_REGISTRY=gcr.io

# New AWS variables
AWS_REGION=us-east-1
CLUSTER_NAME=placement-portal-cluster
ECR_REGISTRY=<account>.dkr.ecr.us-east-1.amazonaws.com
```

### Database Connection
The application now connects to DocumentDB (MongoDB-compatible):
```bash
# Old PostgreSQL connection
DATABASE_URL=postgresql://user:pass@cloudsql/db

# New MongoDB connection
MONGODB_URI=mongodb://user:pass@docdb-cluster.cluster-xyz.us-east-1.docdb.amazonaws.com:27017/placement_db?ssl=true&retryWrites=false
```

### Docker Image References
```yaml
# Old GCR images
image: gcr.io/avid-sunset-435316-a6/placement-backend:v8
image: gcr.io/avid-sunset-435316-a6/placement-frontend:v8

# New ECR images
image: <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-backend:latest
image: <account>.dkr.ecr.us-east-1.amazonaws.com/placement-portal-frontend:latest
```

## 🚢 CI/CD Pipeline Updates

### Jenkins Pipeline Changes
1. **Authentication**: gcloud commands → AWS CLI commands
2. **Image Registry**: GCR login → ECR login
3. **Kubernetes Access**: GKE credentials → EKS update-kubeconfig
4. **Image Paths**: gcr.io URLs → ECR URLs

### Updated Jenkinsfile Stages
```groovy
// Push to ECR
sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
sh "docker push ${IMAGE_BACKEND}:${env.GIT_COMMIT_SHORT}"

// Deploy to EKS
sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
kubectl apply -f k8s/
```

## 🗄️ Database Migration

### From Cloud SQL PostgreSQL to DocumentDB
1. **Export PostgreSQL data**:
```bash
pg_dump postgresql://user:pass@host:5432/db > backup.sql
```

2. **Convert to MongoDB**:
```bash
# Use pgloader or custom scripts to convert PostgreSQL to MongoDB format
# Alternative: Update application to use MongoDB schema
```

3. **Import to DocumentDB**:
```bash
mongoimport --host docdb-cluster.cluster-xyz.us-east-1.docdb.amazonaws.com:27017 \
  --ssl --username user --password pass \
  --db placement_db --collection users --file users.json
```

## 🔐 Security Considerations

### IAM Roles and Policies
- **EKS Service Role**: Manages the EKS cluster
- **Node Group Role**: Allows worker nodes to join cluster
- **Jenkins Role**: ECR push/pull, EKS deployment permissions
- **Application Roles**: Minimum required permissions

### Network Security
- **VPC**: Isolated network environment
- **Security Groups**: Firewall rules for services
- **Private Subnets**: Database and worker nodes
- **NAT Gateways**: Outbound internet access for private subnets

### Secrets Management
- **Kubernetes Secrets**: Database credentials, JWT secrets
- **AWS Secrets Manager** (optional): Enhanced secret management
- **ECR**: Private container registry

## 📊 Monitoring and Logging

### AWS Services
- **CloudWatch**: Metrics, logs, and alarms
- **AWS Load Balancer Controller**: ALB integration
- **Container Insights**: EKS cluster monitoring

### Application Monitoring
```yaml
# Enable CloudWatch logging
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-logging
data:
  flb_log_level: info
  cluster_name: placement-portal-cluster
```

## 🚨 Troubleshooting

### Common Issues

1. **ECR Authentication Failed**:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
```

2. **EKS Access Denied**:
```bash
aws eks update-kubeconfig --region us-east-1 --name placement-portal-cluster
```

3. **DocumentDB Connection Issues**:
```bash
# Ensure security groups allow MongoDB port 27017
# Verify SSL certificates and connection string
```

4. **Load Balancer Not Accessible**:
```bash
# Check ingress controller deployment
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

### Debugging Commands
```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check services
kubectl get services
kubectl describe service placement-backend-service

# Check ingress
kubectl get ingress
kubectl describe ingress placement-ingress

# Check logs
kubectl logs deployment/placement-backend
kubectl logs deployment/placement-frontend
```

## 🧹 Cleanup

To destroy all AWS infrastructure:
```bash
./cleanup-aws.sh
```

Or manually:
```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Destroy Terraform infrastructure
cd infrastructure
terraform destroy
```

## 📝 Migration Checklist

- [x] ✅ Terraform infrastructure migrated to AWS
- [x] ✅ Jenkins setup script updated for AWS
- [x] ✅ Jenkinsfile pipeline migrated to use AWS services
- [x] ✅ Kubernetes deployments updated for ECR images
- [x] ✅ Database configuration updated for DocumentDB
- [x] ✅ Network policies updated for MongoDB
- [x] ✅ SonarQube setup script updated for AWS
- [x] ✅ Deployment and cleanup scripts created
- [ ] ⏳ DNS configuration for load balancer
- [ ] ⏳ SSL certificate setup
- [ ] ⏳ Data migration from PostgreSQL to DocumentDB
- [ ] ⏳ Production deployment and testing

## 🔗 Useful Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS DocumentDB Documentation](https://docs.aws.amazon.com/documentdb/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
