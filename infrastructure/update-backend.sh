#!/bin/bash

# Script to update backend container with latest image
set -e

echo "🔄 Updating backend container..."

# Get backend instance IP
BACKEND_IP=$(terraform output -raw backend_public_ip)
BACKEND_INSTANCE_ID=$(terraform output -raw backend_instance_id)

echo "📍 Backend IP: $BACKEND_IP"
echo "📍 Backend Instance ID: $BACKEND_INSTANCE_ID"

# SSH into backend instance and update container
ssh -i placement-portal-key.pem -o StrictHostKeyChecking=no ubuntu@$BACKEND_IP << 'EOF'
cd /opt/placement-backend

# Source environment variables
source .env

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin 011528267161.dkr.ecr.us-east-1.amazonaws.com

# Stop existing containers
sudo docker-compose down || true

# Pull latest image
sudo docker-compose pull

# Start containers
sudo docker-compose up -d

# Clean up old images
sudo docker image prune -f

echo "✅ Backend container updated successfully"
EOF

echo "🎉 Backend update completed!"
echo "⏳ Waiting 30 seconds for container to start..."
sleep 30

# Test the updated API
echo "🧪 Testing updated API..."
curl -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' http://placement-portal-alb-893991990.us-east-1.elb.amazonaws.com/api/auth/login

echo ""
echo "🧪 Testing health endpoint..."
curl http://placement-portal-alb-893991990.us-east-1.elb.amazonaws.com/api/health
