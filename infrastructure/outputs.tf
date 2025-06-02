# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

# DocumentDB Outputs
output "docdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
  sensitive   = true
}

output "docdb_cluster_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.main.port
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

# Load Balancer Output
output "load_balancer_dns" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
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
  description = "DocumentDB connection string"
  value       = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster.main.endpoint}:${aws_docdb_cluster.main.port}/placement-portal?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
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
