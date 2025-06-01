# Placement Portal - Complete CI/CD Pipeline

A comprehensive DevOps solution for the Placement Portal application featuring Jenkins, SonarQube, Kubernetes, and Google Cloud Platform integration.

## 🏗️ Architecture Overview

This project implements a complete CI/CD pipeline with the following components:

### Infrastructure
- **Google Kubernetes Engine (GKE)** - Container orchestration
- **Jenkins** - CI/CD automation server
- **SonarQube** - Code quality and security analysis
- **Google Cloud SQL** - Managed PostgreSQL database
- **Google Container Registry** - Docker image storage
- **Terraform** - Infrastructure as Code

### Monitoring & Observability
- **Prometheus** - Metrics collection
- **Grafana** - Visualization and dashboards
- **Horizontal Pod Autoscaler** - Auto-scaling
- **Pod Disruption Budgets** - High availability

### Security
- **Network Policies** - Pod-to-pod communication security
- **SSL/TLS Termination** - Managed certificates
- **Container Image Scanning** - Vulnerability detection
- **Secret Management** - Kubernetes secrets

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform](https://www.terraform.io/downloads)
- [Helm](https://helm.sh/docs/intro/install/)

### One-Click Deployment

```bash
# Clone the repository
git clone <your-repo-url>
cd Placement

# Run the complete CI/CD deployment
./deploy-cicd.sh your-gcp-project-id us-central1 us-central1-a
```

### Manual Step-by-Step Deployment

#### 1. Infrastructure Setup

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Create terraform.tfvars with your configuration
cat > terraform.tfvars << EOF
project_id = "your-gcp-project-id"
region = "us-central1"
zone = "us-central1-a"
cluster_name = "placement-portal"
gke_num_nodes = 2
db_username = "placement_user"
db_password = "your-secure-password"
github_owner = "your-github-username"
github_repo = "placement-portal"
EOF

# Deploy infrastructure
terraform plan
terraform apply
```

#### 2. Configure kubectl

```bash
# Get GKE credentials
gcloud container clusters get-credentials placement-portal-cluster \
    --zone us-central1-a \
    --project your-gcp-project-id
```

#### 3. Build and Deploy Applications

```bash
# Configure Docker for GCR
gcloud auth configure-docker

# Build and push images
cd backend
docker build -t gcr.io/your-project-id/placement-backend:latest .
docker push gcr.io/your-project-id/placement-backend:latest

cd ../frontend
docker build -t gcr.io/your-project-id/placement-frontend:latest .
docker push gcr.io/your-project-id/placement-frontend:latest

# Update Kubernetes configurations
cd ../k8s
sed -i 's|PROJECT_ID|your-project-id|g' *.yaml
sed -i 's|IMAGE_TAG|latest|g' *.yaml

# Deploy to Kubernetes
kubectl apply -f secrets.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f frontend-service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f autoscaling.yaml
```

#### 4. Set Up Monitoring

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus and Grafana
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set grafana.adminPassword=admin123 \
    --set grafana.service.type=LoadBalancer
```

## 📋 Post-Deployment Configuration

### Jenkins Setup

1. Access Jenkins at the provided URL
2. Use the initial admin password displayed in the deployment output
3. Install suggested plugins
4. Create an admin user
5. Configure the following:
   - GitHub webhook
   - SonarQube integration
   - Google Cloud credentials
   - Kubernetes plugin configuration

### SonarQube Configuration

1. Access SonarQube at the provided URL
2. Default credentials: admin/admin
3. Change the default password
4. Create a new project for "placement-portal"
5. Generate a project token for Jenkins integration

### DNS Configuration

1. Get the load balancer IP:
   ```bash
   kubectl get ingress placement-portal-ingress
   ```
2. Configure your domain DNS:
   - A record: `placement-portal.com` → Load Balancer IP
   - A record: `www.placement-portal.com` → Load Balancer IP
   - A record: `api.placement-portal.com` → Load Balancer IP

## 🔄 CI/CD Pipeline Flow

### Development Workflow

1. **Code Commit** - Developer pushes code to GitHub
2. **Webhook Trigger** - GitHub webhook triggers Jenkins pipeline
3. **Code Quality** - SonarQube analyzes code quality and security
4. **Build** - Docker images are built and pushed to GCR
5. **Security Scan** - Container images are scanned for vulnerabilities
6. **Deploy to Staging** - Application deployed to staging namespace
7. **Integration Tests** - Automated tests run against staging environment
8. **Manual Approval** - Production deployment requires manual approval
9. **Production Deployment** - Application deployed to production
10. **Post-deployment Tests** - Smoke tests verify production deployment

### Pipeline Stages

```groovy
// Jenkinsfile pipeline stages:
1. Checkout
2. Install Dependencies (Parallel: Backend + Frontend)
3. Code Quality & Security (Parallel: Lint, Test, SonarQube, Security Scan)
4. Quality Gate
5. Build Docker Images (Parallel: Backend + Frontend)
6. Security Scanning - Images (Parallel)
7. Deploy to Staging (develop branch only)
8. Integration Tests (develop branch only)
9. Deploy to Production (main branch only, manual approval)
10. Post-deployment Tests
```

## 🔧 Environment Configuration

### Environment Variables

Create the following secrets in Kubernetes:

```yaml
# Database connection
MONGODB_URI: "mongodb://user:password@host:27017/placement_db"

# Authentication
JWT_SECRET: "your-jwt-secret"

# Cache (Redis)
REDIS_URL: "redis://redis-host:6379"

# Environment-specific
NODE_ENV: "production" | "staging" | "development"
```

### Scaling Configuration

The application automatically scales based on:
- CPU utilization (70% threshold)
- Memory utilization (80% threshold)
- Minimum 3 replicas, maximum 10 replicas for backend
- Minimum 3 replicas, maximum 8 replicas for frontend

## 📊 Monitoring and Observability

### Prometheus Metrics

Access Prometheus at: `http://<prometheus-loadbalancer-ip>:9090`

Key metrics monitored:
- HTTP request duration
- Database connection pool
- Memory and CPU usage
- Error rates
- Request throughput

### Grafana Dashboards

Access Grafana at: `http://<grafana-loadbalancer-ip>:3000`
- Username: admin
- Password: admin123

Pre-configured dashboards:
- Application performance
- Infrastructure metrics
- Kubernetes cluster health
- Database performance

### Log Aggregation

Application logs are automatically collected by GKE and available in:
- Google Cloud Logging
- Prometheus/Grafana stack

## 🛡️ Security Features

### Network Security
- Network policies restrict pod-to-pod communication
- Ingress controller with SSL termination
- Rate limiting on API endpoints

### Container Security
- Non-root containers
- Read-only root filesystems
- Dropped capabilities
- Security scanning of container images

### Data Security
- Secrets stored in Kubernetes secrets
- Database encryption at rest
- TLS encryption for all communication

## 🔍 Troubleshooting

### Common Issues

1. **Jenkins not accessible**
   ```bash
   # Check Jenkins pod status
   gcloud compute ssh jenkins-server --zone=us-central1-a
   sudo systemctl status jenkins
   ```

2. **Pods not starting**
   ```bash
   kubectl get pods
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

3. **Database connection issues**
   ```bash
   # Check database connectivity
   kubectl exec -it <backend-pod> -- nc -zv <db-host> 5432
   ```

4. **SSL certificate issues**
   ```bash
   # Check managed certificate status
   kubectl describe managedcertificate placement-portal-ssl
   ```

### Debug Commands

```bash
# Check cluster status
kubectl cluster-info

# View all resources
kubectl get all --all-namespaces

# Check ingress status
kubectl get ingress

# View HPA status
kubectl get hpa

# Check pod resource usage
kubectl top pods
```

## 📈 Performance Optimization

### Resource Optimization
- CPU and memory requests/limits properly set
- Horizontal Pod Autoscaler configured
- Pod Disruption Budgets for high availability

### Caching Strategy
- Redis cache for session management
- CDN integration for static assets
- Database query optimization

### Database Optimization
- Connection pooling
- Query optimization
- Automated backups

## 🔄 Maintenance

### Regular Tasks

1. **Weekly**
   - Review Grafana dashboards
   - Check SonarQube quality gates
   - Update container images

2. **Monthly**
   - Security patch updates
   - Performance review
   - Cost optimization review

3. **Quarterly**
   - Disaster recovery testing
   - Security audit
   - Infrastructure review

### Backup Strategy

- Database: Automated daily backups with 30-day retention
- Configuration: Git repository with all Kubernetes manifests
- Monitoring: Prometheus data retention for 15 days

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review application logs in Grafana
3. Check cluster status with kubectl
4. Contact the DevOps team

## 📝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request
5. Pipeline will automatically run tests and quality checks

---

**Note**: This is a production-ready CI/CD pipeline. Ensure you understand all security implications and have proper monitoring in place before deploying to production environments.