# 🚀 Placement Portal - One-Click Deployment Guide

This infrastructure is **pre-configured with all fixes** to work perfectly in one go! No manual intervention needed.

## ✅ What's Already Fixed

All the issues that caused the "Bad Gateway" error have been resolved:

1. **✅ Single Instance Architecture**: Exactly 4 instances (1 frontend, 1 backend, 1 Jenkins, 1 SonarQube)
2. **✅ Fixed Setup Scripts**: Added missing `unzip`, `curl`, and Docker Compose installation
3. **✅ Fixed Health Checks**: Backend health check uses correct endpoint (`/` instead of `/api/health`)
4. **✅ Fixed Frontend Nginx**: Custom nginx config points to actual backend IP (no more Docker service name errors)
5. **✅ Fixed Dependencies**: Frontend waits for backend to be created first
6. **✅ Fixed DocumentDB Connection**: Proper SSL/TLS configuration for DocumentDB
7. **✅ Fixed API Routing**: ALB correctly routes `/api/*` to backend
8. **✅ Cost Optimized**: Removed expensive Auto Scaling Groups

## 🏗️ Infrastructure Overview

**Exactly 5 EC2 Instances:**
- **Frontend Instance** (t3.micro): Serves React app with fixed nginx proxy
- **Backend Instance** (t3.micro): Node.js API server
- **MongoDB Instance** (t3.small): Database server (no authentication)
- **Jenkins Instance** (t3.medium): CI/CD pipeline
- **SonarQube Instance** (t3.medium): Code quality analysis

**Additional Resources:**
- Application Load Balancer with health checks
- ECR repositories for Docker images
- S3 bucket for artifacts
- VPC with public/private subnets

### 🔐 Default Test Credentials

After deployment, you can login with these test accounts:
- **Admin**: `username=admin` / `password=admin123`
- **Student**: `username=1ms22cs001` / `password=student123`

## 🚀 Quick Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed
- SSH key pair named `placement-portal-key` in AWS

### Deploy Everything
```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Plan deployment (optional - review changes)
terraform plan

# Deploy everything
terraform apply -auto-approve

# Test deployment (wait 5-10 minutes after apply)
./test-deployment.sh
```

## 🌐 Access URLs

After deployment, you'll get these URLs:

```bash
# Get all URLs
terraform output

# Specific URLs
terraform output application_url    # Main application
terraform output jenkins_url       # Jenkins CI/CD
terraform output sonarqube_url     # SonarQube
```

## ⏱️ Expected Timeline

- **Terraform Apply**: ~5-10 minutes
- **Instance Initialization**: ~5-10 minutes
- **Total Time**: ~15-20 minutes

## 🔍 Troubleshooting

If you encounter any issues:

1. **Check target health**:
   ```bash
   ./test-deployment.sh
   ```

2. **View instance logs**:
   ```bash
   # SSH into instances (replace IP with actual IP from terraform output)
   ssh -i placement-portal-key.pem ubuntu@<instance-ip>
   sudo docker logs <container-name>
   ```

3. **Common Issues**:
   - **503 errors**: Instances still initializing (wait 5-10 minutes)
   - **SSH issues**: Ensure `placement-portal-key.pem` exists and has correct permissions
   - **Permission errors**: Check AWS credentials and IAM permissions

## 🧹 Cleanup

To destroy all resources:
```bash
terraform destroy -auto-approve
```

## 💰 Cost Estimate

**Monthly cost (us-east-1)**:
- Frontend (t3.micro): ~$8
- Backend (t3.micro): ~$8
- MongoDB (t3.small): ~$15
- Jenkins (t3.medium): ~$30
- SonarQube (t3.medium): ~$30
- Load Balancer: ~$20
- **Total**: ~$111/month

## 🎯 Success Indicators

✅ **Deployment Successful When**:
- `terraform apply` completes without errors
- `./test-deployment.sh` shows all services healthy
- Application accessible at the provided URL
- No "Bad Gateway" errors

## 🔧 What Happens During Deployment

1. **Infrastructure Creation** (5 mins): VPC, subnets, security groups, load balancer
2. **Instance Launch** (2 mins): 4 EC2 instances start
3. **Software Installation** (5 mins): Docker, AWS CLI, application setup
4. **Container Deployment** (3 mins): Pull and start Docker containers
5. **Health Checks** (5 mins): Load balancer verifies instance health

**🎉 Your application will be ready in ~20 minutes with zero manual intervention!**
