#!/bin/bash

# Run this script on the Jenkins server to configure kubectl access to EKS

# Configure AWS credentials for jenkins user
sudo -u jenkins aws configure set region us-east-1

# Update kubeconfig for jenkins user
sudo -u jenkins aws eks update-kubeconfig --region us-east-1 --name placement-portal-cluster

# Verify access
sudo -u jenkins kubectl get nodes

echo "Jenkins is now configured to access EKS cluster"
