#!/bin/bash

# Jenkins Setup Script for Amazon Linux 2 (Official AWS Documentation)
set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting Jenkins installation on Amazon Linux using official AWS guide..."

# Update system packages
yum update -y

# Add Jenkins repository
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import Jenkins key
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade packages
yum upgrade -y

# Install Java 17 (as recommended in AWS docs)
yum install java-17-amazon-corretto -y

# Install Jenkins
yum install jenkins -y

# Enable Jenkins service to start at boot
systemctl enable jenkins

# Start Jenkins as a service
systemctl start jenkins

# Install additional tools for CI/CD
# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker jenkins
usermod -aG docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
./aws/install

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Git
yum install -y git

# Set correct permissions
chown -R jenkins:jenkins /var/lib/jenkins
mkdir -p /var/lib/jenkins/.kube
mkdir -p /var/lib/jenkins/.aws
chown jenkins:jenkins /var/lib/jenkins/.kube
chown jenkins:jenkins /var/lib/jenkins/.aws

echo "Jenkins installation completed successfully!"
echo "Initial admin password location: /var/lib/jenkins/secrets/initialAdminPassword"
echo "Jenkins should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Check Jenkins status with: sudo systemctl status jenkins"
