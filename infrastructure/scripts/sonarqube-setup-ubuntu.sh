#!/bin/bash

# SonarQube Setup Script for Ubuntu 22.04 LTS
set -e

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting SonarQube installation on Ubuntu 22.04 LTS..."

# Update system packages
apt-get update -y

# Install prerequisites
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates unzip

# Install Java 17 (required for SonarQube)
apt-get install -y openjdk-17-jdk

# Set JAVA_HOME
echo 'JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Install PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create SonarQube database and user
sudo -u postgres psql -c "CREATE USER sonarqube WITH PASSWORD 'sonarpass';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonarqube;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;"

# Create sonarqube user
useradd -r -s /bin/bash sonarqube

# Download and install SonarQube
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip
unzip sonarqube-9.9.2.77730.zip
mv sonarqube-9.9.2.77730 sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube
cat > /opt/sonarqube/conf/sonar.properties << EOF
sonar.jdbc.username=sonarqube
sonar.jdbc.password=sonarpass
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOF

# Configure system limits
cat > /etc/sysctl.d/99-sonarqube.conf << EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

cat > /etc/security/limits.d/99-sonarqube.conf << EOF
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-sonarqube.conf

# Create systemd service
cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start SonarQube
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

# Install additional tools
apt-get install -y git vim htop

echo "SonarQube installation completed!"
echo "Access SonarQube at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Default credentials: admin/admin"

# Display service status
systemctl status sonarqube --no-pager

echo "Setup completed successfully!"
