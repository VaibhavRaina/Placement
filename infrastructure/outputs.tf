// Expose the cluster details for downstream consumption
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
}

output "cluster_region" {
  description = "The region of the GKE cluster"
  value       = var.region
}
