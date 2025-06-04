# 🔧 Configuration Guide for Placement Portal CI/CD Pipeline

This guide walks you through all the configurations needed to deploy your complete CI/CD pipeline.

## ✅ Pre-Deployment Configuration Checklist

### 1. **Update Required Configuration Files**

Before running the deployment, you MUST update these files with your specific values:

#### A. GitHub Repository Settings (CRITICAL)
Update `infrastructure/terraform.tfvars`:
```bash
github_owner = "your-actual-github-username"  # Replace with your GitHub username
github_repo = "placement-portal"              # Your repository name
```

#### B. SonarQube Project Configuration
Update `sonar-project.properties`:
```properties
sonar.projectKey=placement-portal-avid-sunset-435316-a6
sonar.projectName=Placement Portal
sonar.projectVersion=1.0
sonar.sources=.
sonar.exclusions=**/node_modules/**,**/coverage/**,**/*.test.js,**/*.spec.js,**/dist/**
```

### 2. **AWS Authentication & Setup**

```bash
# 1. Configure AWS credentials
aws configure

# 2. Set your default region (e.g., us-east-1)
aws configure set default.region us-east-1

# 3. Verify authentication
aws sts get-caller-identity
```

### 3. **Deploy the Infrastructure**

```bash
# Make deployment script executable
chmod +x deploy-aws.sh

# Run the complete deployment
./deploy-aws.sh
```

## ⚙️ Post-Deployment Configuration Required

### 4. **Jenkins Configuration** (After Infrastructure Deployment)

The deployment script will output the Jenkins URL and initial password. Configure:

#### A. Initial Setup
1. Access Jenkins at: `http://JENKINS_IP:8080`
2. Use the initial admin password from deployment output
3. Install suggested plugins + these additional ones:
   - SonarQube Scanner
   - Amazon ECR
   - Kubernetes
   - Docker Pipeline
   - GitHub Integration

#### B. Global Tool Configuration
Navigate to `Manage Jenkins > Global Tool Configuration`:

**NodeJS Installation:**
- Name: `18`
- Version: `NodeJS 18.x`
- Global npm packages: `npm@latest`

**SonarQube Scanner:**
- Name: `SonarQubeScanner`
- Install automatically: ✅
- Version: Latest

#### C. System Configuration
Navigate to `Manage Jenkins > Configure System`:

**SonarQube Servers:**
- Name: `SonarQube`
- Server URL: `http://SONARQUBE_IP:9000`
- Server authentication token: (Get from SonarQube setup below)

**AWS Configuration:**
- Configure AWS credentials for ECR access
- Configure kubectl access to EKS cluster

### 5. **SonarQube Configuration**

#### A. Initial Setup
1. Access SonarQube at: `http://SONARQUBE_IP:9000`
2. Default login: `admin/admin`
3. Change password when prompted

#### B. Project Setup
1. Create new project: `placement-portal`
2. Generate project token for Jenkins integration
3. Set quality gate rules (recommended: default)

### 6. **Kubernetes Secrets Configuration**

After deployment, update the secrets with real values:

```bash
# Connect to your EKS cluster
aws eks update-kubeconfig --region us-east-1 --name placement-portal-cluster

# Update database secret (replace with your actual MongoDB URI)
kubectl create secret generic database-secret \
  --from-literal=mongodb-uri='mongodb://placement_user:PlacementSecure2025!@your-db-host:27017/placement_db' \
  --dry-run=client -o yaml | kubectl apply -f -

# Update application secrets
kubectl create secret generic app-secret \
  --from-literal=jwt-secret='your-super-secure-jwt-secret-key-here-min-32-chars' \
  --dry-run=client -o yaml | kubectl apply -f -

# Update cache secret if using Redis
kubectl create secret generic cache-secret \
  --from-literal=redis-url='redis://your-redis-host:6379' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 7. **GitHub Webhook Configuration**

#### A. Repository Settings
1. Go to your GitHub repository
2. Settings > Webhooks > Add webhook
3. Payload URL: `http://JENKINS_IP:8080/github-webhook/`
4. Content type: `application/json`
5. Events: `Push` and `Pull requests`

#### B. Branch Protection (Recommended)
Set up branch protection for `main`:
- Require pull request reviews
- Require status checks to pass (Jenkins pipeline)
- Include administrators

### 8. **Domain Configuration** (Optional but Recommended)

If you have a domain, configure DNS:

```bash
# Get the load balancer IP
kubectl get ingress placement-portal-ingress

# Configure DNS A records:
# placement-portal.com → Load Balancer IP
# www.placement-portal.com → Load Balancer IP  
# api.placement-portal.com → Load Balancer IP
```

## 🚦 Testing Your Configuration

### 9. **Verify Deployment**

```bash
# Check all pods are running
kubectl get pods --all-namespaces

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# Test application endpoints
curl http://LOAD_BALANCER_IP  # Frontend
curl http://LOAD_BALANCER_IP/api/health  # Backend health check
```

### 10. **Test CI/CD Pipeline**

1. **Create a test branch:**
   ```bash
   git checkout -b test-pipeline
   git push origin test-pipeline
   ```

2. **Make a small change and push:**
   ```bash
   echo "# Test change" >> README.md
   git add README.md
   git commit -m "Test CI/CD pipeline"
   git push origin test-pipeline
   ```

3. **Monitor Jenkins pipeline execution**

4. **Test staging deployment** (if using develop branch)

5. **Test production deployment** (if using main branch)

## 🔍 Troubleshooting Common Configuration Issues

### Jenkins Not Accessible
```bash
# Check Jenkins EC2 instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=placement-portal-jenkins"

# SSH into Jenkins server (replace with your key file)
ssh -i placement-portal-key.pem ubuntu@JENKINS_IP

# Check Jenkins service
sudo systemctl status jenkins
sudo journalctl -u jenkins -f
```

### SonarQube Not Starting
```bash
# SSH into SonarQube server (replace with your key file)
ssh -i placement-portal-key.pem ubuntu@SONARQUBE_IP

# Check SonarQube service
sudo systemctl status sonarqube
sudo journalctl -u sonarqube -f

# Check SonarQube logs
sudo tail -f /opt/sonarqube/logs/sonar.log
```

### Kubernetes Deployment Issues
```bash
# Check pod status
kubectl get pods -o wide

# Check specific pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>

# Check secrets
kubectl get secrets
kubectl describe secret database-secret
```

### Database Connection Issues
```bash
# Test database connectivity from a pod
kubectl run test-db --image=postgres:14 --rm -it -- bash
# Inside the pod:
pg_isready -h <db-host> -p 5432
```

## 🎯 Configuration Validation Commands

Run these commands to validate your configuration:

```bash
# Validate Terraform configuration
cd infrastructure
terraform validate
terraform plan

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f k8s/

# Test Docker builds locally
cd backend && docker build -t test-backend .
cd ../frontend && docker build -t test-frontend .

# Validate SonarQube project
sonar-scanner -Dsonar.host.url=http://SONARQUBE_IP:9000 \
              -Dsonar.login=YOUR_TOKEN \
              -Dsonar.projectKey=placement-portal
```

## 📝 Required Manual Updates Summary

**BEFORE DEPLOYMENT:**
1. ✅ Update `infrastructure/terraform.tfvars` with your GitHub username/repo
2. ✅ Update `sonar-project.properties` with your project details

**AFTER DEPLOYMENT:**
1. ⚙️ Complete Jenkins initial setup and plugin installation
2. ⚙️ Configure SonarQube project and generate token
3. ⚙️ Update Kubernetes secrets with real database credentials
4. ⚙️ Set up GitHub webhook
5. ⚙️ Configure DNS (if using custom domain)

**OPTIONAL BUT RECOMMENDED:**
1. 🔐 Set up branch protection rules
2. 📊 Configure monitoring alerts
3. 🔒 Enable additional security scanning
4. 📧 Set up notification channels (Slack, email)

---

**Next Step:** Run `./deploy-aws.sh` to start the deployment!