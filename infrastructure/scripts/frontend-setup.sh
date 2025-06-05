#!/bin/bash

# Frontend Application Setup Script
set -e

# Variables
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry}"
BACKEND_URL="${backend_url}"

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

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Create application directory
mkdir -p /opt/placement-frontend
cd /opt/placement-frontend

# Create environment file
cat > .env << EOF
NODE_ENV=production
REACT_APP_API_URL=$BACKEND_URL
AWS_REGION=$AWS_REGION
EOF

# Create custom nginx configuration to fix backend connectivity
cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    upstream backend {
        server ${backend_ip}:5000;
    }

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
            try_files \$uri \$uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Server \$host;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

# Create Docker Compose file
cat > docker-compose.yml << EOF
version: '3.8'
services:
  frontend:
    image: $ECR_REGISTRY/placement-portal-frontend:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    env_file:
      - .env
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-group: /aws/ec2/placement-frontend
        awslogs-region: $AWS_REGION
        awslogs-stream: frontend-\$(hostname)
EOF

# Create deployment script
cat > deploy.sh << EOF
#!/bin/bash
set -e

# Source environment variables
source .env

# Login to ECR
aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

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
response=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:80/ || echo "000")
if [ "$response" = "200" ]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x health-check.sh

# Create systemd service for health monitoring
cat > /etc/systemd/system/frontend-health.service << EOF
[Unit]
Description=Frontend Health Check
After=docker.service

[Service]
Type=oneshot
ExecStart=/opt/placement-frontend/health-check.sh
User=ubuntu
WorkingDirectory=/opt/placement-frontend

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/frontend-health.timer << EOF
[Unit]
Description=Run Frontend Health Check every 30 seconds
Requires=frontend-health.service

[Timer]
OnCalendar=*:*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable health check timer
systemctl daemon-reload
systemctl enable frontend-health.timer
systemctl start frontend-health.timer

# Create CloudWatch log group
aws logs create-log-group --log-group-name /aws/ec2/placement-frontend --region $AWS_REGION || true

# Initial deployment
./deploy.sh

# Setup log rotation
cat > /etc/logrotate.d/placement-frontend << EOF
/var/log/placement-frontend/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

echo "Frontend setup completed successfully"
