#!/bin/bash

# SonarQube Setup Script
set -e

echo "Starting SonarQube installation..."

# Update system
apt-get update -y
apt-get upgrade -y

# Install Java 11
apt-get install -y openjdk-11-jdk

# Install PostgreSQL for SonarQube database
apt-get install -y postgresql postgresql-contrib

# Configure PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create SonarQube database and user
sudo -u postgres psql -c "CREATE DATABASE sonarqube;"
sudo -u postgres psql -c "CREATE USER sonarqube WITH PASSWORD 'sonarqube';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;"
sudo -u postgres psql -c "ALTER USER sonarqube CREATEDB;"

# Configure system limits for SonarQube
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
sysctl -p

echo "sonarqube   -   nofile   131072" >> /etc/security/limits.conf
echo "sonarqube   -   nproc    8192" >> /etc/security/limits.conf

# Create SonarQube user
useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube

# Download and install SonarQube
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip
unzip sonarqube-9.9.2.77730.zip
mv sonarqube-9.9.2.77730 sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube

# Configure SonarQube
cat > /opt/sonarqube/conf/sonar.properties << EOF
# Database settings
sonar.jdbc.username=sonarqube
sonar.jdbc.password=sonarqube
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube

# Web server settings
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch settings
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError

# Application settings
sonar.ce.javaOpts=-Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError
EOF

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

# Start and enable SonarQube
systemctl daemon-reload
systemctl start sonarqube
systemctl enable sonarqube

# Install SonarQube Scanner
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
unzip sonar-scanner-cli-4.8.0.2856-linux.zip
mv sonar-scanner-4.8.0.2856-linux sonar-scanner
chown -R sonarqube:sonarqube /opt/sonar-scanner

# Add SonarQube Scanner to PATH
echo 'export PATH=$PATH:/opt/sonar-scanner/bin' >> /etc/environment

# Configure firewall
ufw allow 9000

# Wait for SonarQube to start
echo "Waiting for SonarQube to start..."
sleep 60

# Check if SonarQube is running
while ! curl -sSf http://localhost:9000 > /dev/null; do
    echo "Waiting for SonarQube to be ready..."
    sleep 10
done

echo "SonarQube installation completed!"
echo "Access SonarQube at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Default credentials: admin/admin"