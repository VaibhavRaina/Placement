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

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 4
}

variable "node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
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

variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins instance"
  type        = string
  default     = "ami-0453ec754f44f9a4a" # Amazon Linux 2 in us-east-1
}

variable "sonarqube_ami_id" {
  description = "AMI ID for SonarQube instance"
  type        = string
  default     = "ami-0453ec754f44f9a4a" # Amazon Linux 2 in us-east-1
}

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
