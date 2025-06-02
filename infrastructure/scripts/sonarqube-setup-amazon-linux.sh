#!/bin/bash

# SonarQube Setup Script for Amazon Linux 2
set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting SonarQube installation on Amazon Linux..."

# Update system
yum update -y

# Install Java 11
yum install -y java-11-amazon-corretto-headless

# Install wget and unzip
yum install -y wget unzip

# Create sonar user
useradd sonar

# Download and install SonarQube
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.1.69595.zip
unzip sonarqube-9.9.1.69595.zip
mv sonarqube-9.9.1.69595 sonarqube
chown -R sonar:sonar sonarqube

# Configure SonarQube to run as service
cat > /etc/systemd/system/sonarqube.service << 'EOF'
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Set kernel parameters for SonarQube
echo 'vm.max_map_count=524288' >> /etc/sysctl.conf
echo 'fs.file-max=131072' >> /etc/sysctl.conf
sysctl -p

# Set ulimits for sonar user
echo 'sonar   -   nofile   131072' >> /etc/security/limits.conf
echo 'sonar   -   nproc    8192' >> /etc/security/limits.conf

# Enable and start SonarQube
systemctl enable sonarqube
systemctl start sonarqube

echo "SonarQube installation completed successfully!"
echo "SonarQube should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Default credentials: admin/admin"
