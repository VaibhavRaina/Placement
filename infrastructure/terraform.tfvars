# Terraform variables file for AWS deployment
aws_region = "us-east-1"
project_name = "placement-portal"
environment = "dev"
vpc_cidr = "10.0.0.0/16"

# EC2 Instance Configuration
backend_instance_type = "t3.small"
frontend_instance_type = "t3.micro"
backend_min_size = 1
backend_max_size = 4
backend_desired_size = 2
frontend_min_size = 1
frontend_max_size = 3
frontend_desired_size = 2

# Database Configuration
db_username = "placement"
db_password = "admin123"
db_instance_class = "db.t3.medium"

# GitHub Configuration
github_owner = "VaibhavRaina"
github_repo = "Placement"