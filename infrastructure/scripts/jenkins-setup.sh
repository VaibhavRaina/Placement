#!/bin/bash

# Jenkins Setup Script
set -e

echo "Starting Jenkins installation..."

# Update system
apt-get update -y
apt-get upgrade -y

# Install Java 11
apt-get install -y openjdk-11-jdk

# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
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

# Install Google Cloud SDK
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update -y
apt-get install -y google-cloud-cli

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Node.js for building frontend
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Configure Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
sleep 30

# Get initial admin password
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

# Install Jenkins plugins via CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# Wait for Jenkins to be fully ready
while ! curl -sSf http://localhost:8080/login > /dev/null; do
    echo "Waiting for Jenkins to start..."
    sleep 10
done

# Install required plugins
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$JENKINS_PASSWORD install-plugin \
    blueocean \
    docker-workflow \
    kubernetes \
    git \
    github \
    pipeline-stage-view \
    sonar \
    nodejs \
    workspace-cleanup \
    build-timeout \
    timestamper \
    ws-cleanup \
    ant \
    gradle \
    pipeline-github-lib \
    pipeline-githubnotify-step

# Restart Jenkins to apply plugins
systemctl restart jenkins

# Configure firewall
ufw allow 8080
ufw allow 50000

# Create jenkins user directories
mkdir -p /var/lib/jenkins/.kube
chown jenkins:jenkins /var/lib/jenkins/.kube

# Configure gcloud for jenkins user
sudo -u jenkins gcloud auth activate-service-account --key-file=/tmp/jenkins-sa-key.json
sudo -u jenkins gcloud config set project ${project_id}

echo "Jenkins installation completed!"
echo "Initial admin password: $JENKINS_PASSWORD"
echo "Access Jenkins at: http://$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google"):8080"