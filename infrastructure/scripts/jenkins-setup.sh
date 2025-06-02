#!/bin/bash

# Jenkins Setup Script
set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting Jenkins installation..."

# Update system
apt-get update -y

# Install Java 11
apt-get install -y openjdk-11-jdk

# Add Jenkins repository key and repository
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -
echo "deb https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list

# Install Jenkins
apt-get update -y
apt-get install -y jenkins

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker jenkins

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install

# Install Node.js for building frontend
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Configure firewall (disable ufw first, then configure if needed)
systemctl stop ufw || true
systemctl disable ufw || true

# Set correct permissions
chown -R jenkins:jenkins /var/lib/jenkins
mkdir -p /var/lib/jenkins/.kube
mkdir -p /var/lib/jenkins/.aws
chown jenkins:jenkins /var/lib/jenkins/.kube
chown jenkins:jenkins /var/lib/jenkins/.aws

echo "Jenkins installation completed successfully!"
echo "Initial admin password will be available at: /var/lib/jenkins/secrets/initialAdminPassword"

# Configure AWS credentials for jenkins user (will be set via IAM role)
echo "AWS credentials will be provided via IAM role"

echo "Jenkins installation completed!"
echo "Initial admin password: $JENKINS_PASSWORD"
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"