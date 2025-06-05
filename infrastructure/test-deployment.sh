#!/bin/bash

# Test script to verify deployment is working
set -e

echo "🚀 Testing Placement Portal Deployment..."

# Get the application URL from Terraform output
APP_URL=$(terraform output -raw application_url)
JENKINS_URL=$(terraform output -raw jenkins_url)
SONARQUBE_URL=$(terraform output -raw sonarqube_url)

echo "📍 Application URL: $APP_URL"
echo "📍 Jenkins URL: $JENKINS_URL"
echo "📍 SonarQube URL: $SONARQUBE_URL"

# Test frontend
echo "🔍 Testing frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL" || echo "000")
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Frontend is working (HTTP $FRONTEND_STATUS)"
else
    echo "❌ Frontend failed (HTTP $FRONTEND_STATUS)"
    exit 1
fi

# Test backend API endpoint
echo "🔍 Testing backend API endpoint..."
BACKEND_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/api/auth/login" -X POST -H "Content-Type: application/json" -d '{"username":"test","password":"test"}' || echo "000")
if [ "$BACKEND_API_STATUS" = "400" ] || [ "$BACKEND_API_STATUS" = "401" ] || [ "$BACKEND_API_STATUS" = "200" ]; then
    echo "✅ Backend API endpoint is working (HTTP $BACKEND_API_STATUS)"
else
    echo "❌ Backend API endpoint failed (HTTP $BACKEND_API_STATUS)"
    exit 1
fi

# Test backend API authentication
echo "🔍 Testing backend API authentication..."
API_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}' "$APP_URL/api/auth/login" || echo "ERROR")
if [[ "$API_RESPONSE" == *"success"* ]]; then
    echo "✅ Backend API authentication is working (admin login successful)"
elif [[ "$API_RESPONSE" == *"Invalid credentials"* ]]; then
    echo "⚠️  Backend API is working but credentials need to be set up"
else
    echo "⚠️  Backend API response: $API_RESPONSE"
fi

# Test Jenkins
echo "🔍 Testing Jenkins..."
JENKINS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$JENKINS_URL" || echo "000")
if [ "$JENKINS_STATUS" = "200" ] || [ "$JENKINS_STATUS" = "403" ]; then
    echo "✅ Jenkins is accessible (HTTP $JENKINS_STATUS)"
else
    echo "⚠️  Jenkins may still be starting up (HTTP $JENKINS_STATUS)"
fi

# Test SonarQube
echo "🔍 Testing SonarQube..."
SONARQUBE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SONARQUBE_URL" || echo "000")
if [ "$SONARQUBE_STATUS" = "200" ]; then
    echo "✅ SonarQube is accessible (HTTP $SONARQUBE_STATUS)"
else
    echo "⚠️  SonarQube may still be starting up (HTTP $SONARQUBE_STATUS)"
fi

# Check target group health
echo "🔍 Checking target group health..."
FRONTEND_TG_ARN=$(aws elbv2 describe-target-groups --names placement-portal-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region us-east-1)
BACKEND_TG_ARN=$(aws elbv2 describe-target-groups --names placement-portal-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region us-east-1)

FRONTEND_HEALTH=$(aws elbv2 describe-target-health --target-group-arn "$FRONTEND_TG_ARN" --region us-east-1 --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)
BACKEND_HEALTH=$(aws elbv2 describe-target-health --target-group-arn "$BACKEND_TG_ARN" --region us-east-1 --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)

echo "🎯 Frontend target health: $FRONTEND_HEALTH"
echo "🎯 Backend target health: $BACKEND_HEALTH"

if [ "$FRONTEND_HEALTH" = "healthy" ] && [ "$BACKEND_HEALTH" = "healthy" ]; then
    echo "🎉 All services are healthy and working!"
    echo ""
    echo "🌐 Access your application at: $APP_URL"
    echo "🔧 Jenkins CI/CD at: $JENKINS_URL"
    echo "📊 SonarQube at: $SONARQUBE_URL"
    echo ""
    echo "🔐 Test Credentials:"
    echo "   Admin: username=admin / password=admin123"
    echo "   Student: username=1ms22cs001 / password=student123"
    echo ""
    echo "🧪 Quick API Test:"
    echo "   curl -X POST -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}' $APP_URL/api/auth/login"
else
    echo "⚠️  Some services may still be initializing. Wait a few minutes and run this test again."
fi

echo ""
echo "✅ Deployment test completed!"
