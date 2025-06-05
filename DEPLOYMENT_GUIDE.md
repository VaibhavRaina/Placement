# 🚀 Deployment Guide - EC2-Based Infrastructure

This guide covers the deployment of the Placement Portal using cost-effective EC2 infrastructure instead of expensive EKS.

## 📋 Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Docker** installed and running
3. **Terraform** installed (v1.0+)
4. **SSH Key Pair** named `placement-portal-key` in AWS

```bash
# Verify prerequisites
aws sts get-caller-identity
docker --version
terraform --version
```

## 🎯 Deployment Options

### Option 1: Initial Deployment (Recommended for first time)

Use this for the very first deployment when no infrastructure exists:

```bash
./deploy-initial.sh
```

This script will:
- ✅ Deploy all infrastructure with Terraform
- ✅ Build and push Docker images to ECR
- ✅ Wait for Auto Scaling Groups to launch instances
- ✅ Wait for target groups to become healthy
- ✅ Provide deployment summary with URLs

### Option 2: Full Infrastructure Deployment

Use this for complete infrastructure management:

```bash
./deploy-aws.sh
```

This script handles both initial deployment and updates.

### Option 3: Application Updates Only

Use this when infrastructure exists and you only want to update applications:

```bash
./deploy-ec2.sh
```

This script will:
- ✅ Build and push new Docker images
- ✅ Update launch templates with new image tags
- ✅ Trigger rolling deployment with zero downtime
- ✅ Monitor deployment progress

## 🏗️ Infrastructure Overview

### Cost-Effective Architecture
- **Frontend**: 2x t3.micro instances (Auto Scaling: 1-3)
- **Backend**: 2x t3.small instances (Auto Scaling: 1-4)
- **Database**: DocumentDB t3.medium (MongoDB-compatible)
- **Load Balancer**: Application Load Balancer
- **CI/CD**: Jenkins on t3.medium + SonarQube on t3.medium

### Estimated Monthly Cost: $50-75 (vs $150-200 with EKS)

## 🔄 Deployment Process

### 1. Initial Setup
```bash
# Clone repository
git clone <your-repo-url>
cd Placement

# Configure AWS credentials
aws configure

# Run initial deployment
./deploy-initial.sh
```

### 2. Application Updates
```bash
# For application code changes
./deploy-ec2.sh

# For infrastructure changes
./deploy-aws.sh
```

### 3. Monitoring Deployment
```bash
# Check Auto Scaling Groups
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names placement-portal-backend-asg placement-portal-frontend-asg

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <backend-target-group-arn>
```

## 🎛️ CI/CD Pipeline

### Jenkins Pipeline Features
- ✅ **Automated builds** on code changes
- ✅ **SonarQube integration** for code quality
- ✅ **ECR image management** with automatic cleanup
- ✅ **Rolling deployments** with health checks
- ✅ **Zero-downtime updates** using instance refresh

### Pipeline Stages
1. **Checkout** - Get latest code
2. **Test** - Run unit tests
3. **Build** - Create Docker images
4. **Quality Gate** - SonarQube analysis
5. **Deploy** - Rolling update to EC2 instances

## 🔧 Configuration

### Environment Variables
```bash
# Set in deployment scripts
AWS_REGION=us-east-1
IMAGE_TAG=latest
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

### Auto Scaling Configuration
```hcl
# Backend ASG
min_size = 1
max_size = 4
desired_capacity = 2

# Frontend ASG  
min_size = 1
max_size = 3
desired_capacity = 2
```

## 🚨 Troubleshooting

### Common Issues

1. **Launch templates not found**
   ```bash
   # Solution: Run initial deployment first
   ./deploy-initial.sh
   ```

2. **ECR authentication failed**
   ```bash
   # Solution: Re-login to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}
   ```

3. **Target groups unhealthy**
   ```bash
   # Check instance logs
   aws logs describe-log-groups --log-group-name-prefix /aws/ec2/placement
   ```

4. **Instance refresh stuck**
   ```bash
   # Cancel and retry
   aws autoscaling cancel-instance-refresh --auto-scaling-group-name placement-portal-backend-asg
   ./deploy-ec2.sh
   ```

5. **Instances failing health checks after deployment**
   ```bash
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:ACCOUNT_ID:targetgroup/placement-portal-backend-tg/ID
   
   # Check Auto Scaling Group status
   aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names placement-portal-backend-asg
   
   # Wait for Docker containers to start (may take 5-10 minutes)
   # Monitor instance refresh progress
   aws autoscaling describe-instance-refreshes --auto-scaling-group-name placement-portal-backend-asg
   ```

6. **Bad Gateway (502) errors**
   ```bash
   # This is normal during deployment while instances are starting
   # Docker images need time to download and containers to start
   # Wait 5-10 minutes and check again
   curl -I http://placement-portal-alb-893991990.us-east-1.elb.amazonaws.com/api/health
   ```

### Health Checks
```bash
# Application health
curl http://<alb-dns>/api/health
curl http://<alb-dns>/

# Instance health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## 🧹 Cleanup

### Remove All Infrastructure
```bash
./cleanup-aws.sh
```

### Manual Cleanup (if script fails)
```bash
cd infrastructure
terraform destroy -auto-approve
```

## 📊 Monitoring & Logs

### CloudWatch Logs
- **Backend logs**: `/aws/ec2/placement-backend`
- **Frontend logs**: `/aws/ec2/placement-frontend`

### Application URLs
- **Application**: `http://<alb-dns>`
- **Jenkins**: `http://<jenkins-ip>:8080`
- **SonarQube**: `http://<sonarqube-ip>:9000`

## 🔐 Security Features

- ✅ **VPC isolation** with private subnets for applications
- ✅ **Security groups** with minimal required access
- ✅ **IAM roles** with least privilege principles
- ✅ **Encrypted storage** for S3 artifacts
- ✅ **SSL/TLS** ready (certificate can be added to ALB)

## 📈 Scaling

### Manual Scaling
```bash
# Scale backend
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name placement-portal-backend-asg \
  --desired-capacity 3

# Scale frontend  
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name placement-portal-frontend-asg \
  --desired-capacity 3
```

### Auto Scaling Policies
Auto Scaling Groups automatically scale based on:
- CPU utilization
- Target group health
- Custom CloudWatch metrics

---

## 🎉 Success!

Your cost-effective, enterprise-grade deployment is now ready with:
- **60-70% cost savings** compared to EKS
- **Zero-downtime deployments**
- **High availability** across multiple AZs
- **Modern CI/CD pipeline**
- **Production-ready monitoring**
