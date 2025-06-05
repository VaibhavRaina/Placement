#!/bin/bash

# Backend Application Setup Script
set -e

# Variables
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry}"
MONGODB_URI="${mongodb_uri}"
JWT_SECRET="${jwt_secret}"

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y unzip curl

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install SSM Agent (for remote command execution)
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Create application directory
mkdir -p /opt/placement-backend
cd /opt/placement-backend

# Create environment file with proper MongoDB configuration
cat > .env << EOF
NODE_ENV=production
PORT=5000
MONGODB_URI=$MONGODB_URI
JWT_SECRET=$JWT_SECRET
AWS_REGION=$AWS_REGION
EOF

# Create Docker Compose file
cat > docker-compose.yml << EOF
version: '3.8'
services:
  backend:
    image: $ECR_REGISTRY/placement-portal-backend:latest
    ports:
      - "5000:5000"
    env_file:
      - .env
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-group: /aws/ec2/placement-backend
        awslogs-region: $AWS_REGION
        awslogs-stream: backend-\$(hostname)
EOF

# Create deployment script
cat > deploy.sh << EOF
#!/bin/bash
set -e

# Source environment variables
source .env

# Login to ECR
aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Stop existing containers
docker-compose down || true

# Pull latest image
docker-compose pull

# Deploy with zero downtime
docker-compose up -d

# Clean up old images
docker image prune -f
EOF

chmod +x deploy.sh

# Create health check script
cat > health-check.sh << 'EOF'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:5000/health || echo "000")
if [ "$response" = "200" ]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x health-check.sh

# Create systemd service for health monitoring
cat > /etc/systemd/system/backend-health.service << EOF
[Unit]
Description=Backend Health Check
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/placement-backend/health-check.sh
User=ubuntu
WorkingDirectory=/opt/placement-backend

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/backend-health.timer << EOF
[Unit]
Description=Run Backend Health Check every 30 seconds
Requires=backend-health.service

[Timer]
OnCalendar=*:*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable health check timer
systemctl daemon-reload
systemctl enable backend-health.timer
systemctl start backend-health.timer

# Create CloudWatch log group
aws logs create-log-group --log-group-name /aws/ec2/placement-backend --region $AWS_REGION || true

# Initial deployment
./deploy.sh

# Setup log rotation
cat > /etc/logrotate.d/placement-backend << EOF
/var/log/placement-backend/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

echo "Backend setup completed successfully"
