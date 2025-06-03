# Terraform variables file for AWS deployment
aws_region = "us-east-1"
project_name = "placement-portal"
environment = "dev"
vpc_cidr = "10.0.0.0/16"
eks_version = "1.29"
node_instance_type = "t3.small"
node_desired_size = 2
node_max_size = 4
node_min_size = 1
db_username = "placement"
db_password = "admin123"
db_instance_class = "db.t3.medium"
jenkins_ami_id = "ami-0a7d80731ae1b2435"
sonarqube_ami_id = "ami-0a7d80731ae1b2435"
github_owner = "VaibhavRaina"
github_repo = "Placement"