# Instance Outputs
output "backend_instance_id" {
  description = "ID of the backend instance"
  value       = aws_instance.backend.id
}

output "frontend_instance_id" {
  description = "ID of the frontend instance"
  value       = aws_instance.frontend.id
}

output "backend_public_ip" {
  description = "Public IP of the backend instance"
  value       = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  description = "Public IP of the frontend instance"
  value       = aws_instance.frontend.public_ip
}

output "mongodb_instance_id" {
  description = "ID of the MongoDB instance"
  value       = aws_instance.mongodb.id
}

output "mongodb_public_ip" {
  description = "Public IP of the MongoDB instance"
  value       = aws_instance.mongodb.public_ip
}

output "mongodb_private_ip" {
  description = "Private IP of the MongoDB instance"
  value       = aws_instance.mongodb.private_ip
}

# Application URL
output "application_url" {
  description = "Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "load_balancer_dns" {
  description = "Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

# MongoDB Outputs
output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://${aws_instance.mongodb.public_ip}:27017/placement_db"
  sensitive   = true
}

# ECR Repository Outputs
output "backend_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}



# Jenkins Instance Output
output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins server URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

# SonarQube Instance Output
output "sonarqube_public_ip" {
  description = "SonarQube server public IP"
  value       = aws_eip.sonarqube.public_ip
}

output "sonarqube_url" {
  description = "SonarQube server URL"
  value       = "http://${aws_eip.sonarqube.public_ip}:9000"
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Database Connection String
output "database_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://${aws_instance.mongodb.public_ip}:27017/placement_db"
  sensitive   = true
}

# S3 Artifacts Bucket Output
output "artifacts_bucket_name" {
  description = "S3 bucket for storing artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

# ECR Registry URL
output "container_registry_url" {
  description = "ECR Registry URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}
