variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "placement-portal"
}

variable "gke_num_nodes" {
  description = "Number of GKE nodes"
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
