// Expose the cluster details for downstream consumption
output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.placement_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.placement_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.placement_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "database_ip" {
  description = "Cloud SQL instance IP"
  value       = google_sql_database_instance.main.ip_address[0].ip_address
  sensitive   = true
}

output "static_ip" {
  description = "Static IP for load balancer"
  value       = google_compute_global_address.default.address
}

output "artifacts_bucket" {
  description = "GCS bucket for artifacts"
  value       = google_storage_bucket.artifacts.name
}

output "jenkins_ip" {
  description = "Jenkins server external IP"
  value       = google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip
}

output "sonarqube_ip" {
  description = "SonarQube server external IP"
  value       = google_compute_instance.sonarqube.network_interface[0].access_config[0].nat_ip
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.placement_cluster.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.placement_cluster.endpoint
}

output "database_connection_string" {
  description = "Database connection string"
  value       = "postgresql://${var.db_username}:${var.db_password}@${google_sql_database_instance.main.public_ip_address}:5432/${google_sql_database.database.name}"
  sensitive   = true
}

output "load_balancer_ip" {
  description = "Load balancer IP address"
  value       = google_compute_global_address.default.address
}

output "container_registry_url" {
  description = "Container Registry URL"
  value       = "gcr.io/${var.project_id}"
}

output "jenkins_url" {
  description = "Jenkins access URL"
  value       = "http://${google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube access URL"
  value       = "http://${google_compute_instance.sonarqube.network_interface[0].access_config[0].nat_ip}:9000"
}
