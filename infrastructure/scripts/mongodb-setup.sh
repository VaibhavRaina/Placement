#!/bin/bash

# MongoDB Setup Script for Ubuntu
set -e

# Variables
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"

# Log all output
exec > >(tee /var/log/mongodb-setup.log) 2>&1

echo "Starting MongoDB setup..."

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget gnupg lsb-release

# Install MongoDB from Ubuntu repository (simpler approach)
apt-get install -y mongodb

# Start and enable MongoDB
systemctl start mongodb
systemctl enable mongodb

# Wait for MongoDB to start
sleep 10

# Configure MongoDB for external connections
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf

# Restart MongoDB to apply configuration
systemctl restart mongodb
sleep 10

# Create database and initial data without authentication first
mongo --eval "
use placement_db;

// Create admin user with username 'admin' and password 'admin123'
// Note: Password will be hashed by the backend when the admin logs in for the first time
db.users.insertOne({
  username: 'admin',
  email: 'admin@placementportal.com',
  password: 'admin123',
  role: 'admin',
  name: 'Admin User',
  createdAt: new Date()
});

// Create test student user with USN and password 'student123'
db.users.insertOne({
  usn: '1ms22cs001',
  email: 'student@placement.com',
  password: 'student123',
  role: 'student',
  name: 'Test Student',
  semester: 6,
  branch: 'Computer Science',
  year: 2022,
  cgpa: 8.5,
  placementStatus: 'Not Placed',
  createdAt: new Date()
});

db.companies.insertOne({
  name: 'Sample Company',
  description: 'A sample company for testing',
  website: 'https://example.com',
  createdAt: new Date()
});

print('MongoDB setup completed successfully!');
print('Admin credentials: username=admin / password=admin123');
print('Student credentials: username=1ms22cs001 / password=student123');
"

# Create MongoDB status check script
cat > /usr/local/bin/mongodb-health-check.sh << 'EOF'
#!/bin/bash
if mongo --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "MongoDB is healthy"
    exit 0
else
    echo "MongoDB is not responding"
    exit 1
fi
EOF

chmod +x /usr/local/bin/mongodb-health-check.sh

# Set up log rotation for MongoDB
cat > /etc/logrotate.d/mongodb << 'EOF'
/var/log/mongodb/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 mongodb mongodb
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/lib/mongodb/mongod.lock 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

# Configure firewall (if ufw is enabled)
if ufw status | grep -q "Status: active"; then
    ufw allow 27017/tcp
fi

echo "MongoDB setup completed successfully!"
echo "Database: placement_db"
echo "Username: $DB_USERNAME"
echo "Connection string: mongodb://$DB_USERNAME:$DB_PASSWORD@$(hostname -I | awk '{print $1}'):27017/placement_db"

# Final health check
/usr/local/bin/mongodb-health-check.sh
