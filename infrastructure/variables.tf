variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "placement-portal"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "backend_instance_type" {
  description = "EC2 instance type for backend instances"
  type        = string
  default     = "t3.small"
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend instances"
  type        = string
  default     = "t3.micro"
}

variable "backend_min_size" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 1
}

variable "backend_max_size" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 4
}

variable "backend_desired_size" {
  description = "Desired number of backend instances"
  type        = number
  default     = 2
}

variable "frontend_min_size" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 1
}

variable "frontend_max_size" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 3
}

variable "frontend_desired_size" {
  description = "Desired number of frontend instances"
  type        = number
  default     = 2
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "placement_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

# AMI IDs are now dynamically fetched using data sources

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "your-github-username"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "placement-portal"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "sonarqube_admin_password" {
  description = "SonarQube admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}
