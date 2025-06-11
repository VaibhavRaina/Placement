#!/bin/bash

# Prometheus Setup Script for Ubuntu
set -e

# Variables
AWS_REGION="${aws_region}"

# Log all output
exec > >(tee /var/log/prometheus-setup.log) 2>&1

echo "Starting Prometheus setup..."

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget

# Create prometheus user
useradd --no-create-home --shell /bin/false prometheus

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus

# Download and install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
tar xvf prometheus-2.47.0.linux-amd64.tar.gz
cd prometheus-2.47.0.linux-amd64

# Copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Copy console files
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus
chown -R prometheus:prometheus /etc/prometheus/consoles
chown -R prometheus:prometheus /etc/prometheus/console_libraries

# Create Prometheus configuration
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'backend'
    static_configs:
      - targets: ['$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-backend" --query "Addresses[0].AssociatedInstance" --output text --region $AWS_REGION | xargs -I {} aws ec2 describe-instances --instance-ids {} --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $AWS_REGION):5000']
    metrics_path: '/api/metrics'
    scrape_interval: 30s

  - job_name: 'frontend'
    static_configs:
      - targets: ['$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-frontend" --query "Addresses[0].AssociatedInstance" --output text --region $AWS_REGION | xargs -I {} aws ec2 describe-instances --instance-ids {} --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $AWS_REGION):80']
    scrape_interval: 30s

  - job_name: 'mongodb'
    static_configs:
      - targets: ['$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-mongodb-eip" --query "Addresses[0].PublicIp" --output text --region $AWS_REGION):27017']
    scrape_interval: 30s

  - job_name: 'jenkins'
    static_configs:
      - targets: ['$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-jenkins-eip" --query "Addresses[0].PublicIp" --output text --region $AWS_REGION):8080']
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: 
        - '$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-backend" --query "Addresses[0].AssociatedInstance" --output text --region $AWS_REGION | xargs -I {} aws ec2 describe-instances --instance-ids {} --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $AWS_REGION):9100'
        - '$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-frontend" --query "Addresses[0].AssociatedInstance" --output text --region $AWS_REGION | xargs -I {} aws ec2 describe-instances --instance-ids {} --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $AWS_REGION):9100'
        - '$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-mongodb-eip" --query "Addresses[0].PublicIp" --output text --region $AWS_REGION):9100'
        - '$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=placement-portal-jenkins-eip" --query "Addresses[0].PublicIp" --output text --region $AWS_REGION):9100'
        - 'localhost:9100'
    scrape_interval: 30s
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service file
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /etc/prometheus/prometheus.yml \\
    --storage.tsdb.path /var/lib/prometheus/ \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Download and install Node Exporter for system metrics
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64
cp node_exporter /usr/local/bin
chown prometheus:prometheus /usr/local/bin/node_exporter

# Create node_exporter systemd service
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
    --web.listen-address=0.0.0.0:9100

[Install]
WantedBy=multi-user.target
EOF

# Install AWS CLI for dynamic target discovery
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Start and enable services
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
systemctl enable node_exporter
systemctl start node_exporter

# Configure firewall (if ufw is enabled)
if ufw status | grep -q "Status: active"; then
    ufw allow 9090/tcp
    ufw allow 9100/tcp
fi

# Create health check script
cat > /usr/local/bin/prometheus-health-check.sh << 'EOF'
#!/bin/bash
if curl -f -s http://localhost:9090/-/healthy > /dev/null; then
    echo "Prometheus is healthy"
    exit 0
else
    echo "Prometheus is not responding"
    exit 1
fi
EOF

chmod +x /usr/local/bin/prometheus-health-check.sh

echo "Prometheus setup completed successfully!"
echo "Prometheus Web UI: http://$(curl -s http://checkip.amazonaws.com):9090"
echo "Node Exporter metrics: http://$(curl -s http://checkip.amazonaws.com):9100/metrics"

# Final health check
sleep 10
/usr/local/bin/prometheus-health-check.sh
