#!/bin/bash

# Jenkins Setup Script for Ubuntu 22.04 LTS
set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting Jenkins installation on Ubuntu 22.04 LTS..."

# Update system packages
apt-get update -y

# Install prerequisites
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Install Java 17 (OpenJDK)
apt-get install -y openjdk-17-jdk

# Add Jenkins repository and key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package list
apt-get update -y

# Install Jenkins
apt-get install -y jenkins

# Enable Jenkins service to start at boot
systemctl enable jenkins

# Start Jenkins as a service
systemctl start jenkins

# Install Docker
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker jenkins
usermod -aG docker ubuntu

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install

# Install Node.js 18 LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install additional tools
apt-get install -y git vim htop

# Set up proper permissions
chown -R jenkins:jenkins /var/lib/jenkins

# Configure Docker daemon to start on boot
systemctl enable docker

# Print status
echo "Jenkins installation completed!"
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Initial admin password can be found at: /var/lib/jenkins/secrets/initialAdminPassword"

# Display services status
systemctl status jenkins --no-pager
systemctl status docker --no-pager

echo "Setup completed successfully!"
