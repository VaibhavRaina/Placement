# Google Cloud Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = true
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
  depends_on              = [google_project_service.apis]
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.name
  
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }
  
  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }
}

# Private services connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Cloud SQL (MongoDB alternative - using PostgreSQL)
resource "google_sql_database_instance" "main" {
  name             = "${var.cluster_name}-db"
  database_version = "POSTGRES_14"
  region           = var.region
  
  settings {
    tier = "db-f1-micro"
    
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }
  }
  
  deletion_protection = false
  depends_on          = [google_project_service.apis, google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "database" {
  name     = "placement_db"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

# Cloud SQL for MongoDB (managed database)
resource "google_sql_database_instance" "mongodb" {
  name             = "placement-mongodb"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled = true
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }
  }

  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_vpc_connection]
}

# GKE cluster setup
resource "google_container_cluster" "placement_cluster" {
  name     = "placement-portal-cluster"
  location = var.zone
  
  remove_default_node_pool = true
  initial_node_count       = 1
  
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-ranges"
    services_secondary_range_name = "services-range"
  }
  
  network_policy {
    enabled = false
  }
  
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  
  depends_on = [google_project_service.apis]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.placement_cluster.name
  node_count = var.gke_num_nodes
  
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    labels = {
      env = var.project_id
    }
    
    machine_type = "e2-micro"
    disk_size_gb = 20
    disk_type    = "pd-standard"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
  
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}

# Jenkins VM Instance
resource "google_compute_instance" "jenkins" {
  name         = "jenkins-server"
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = templatefile("${path.module}/scripts/jenkins-setup.sh", {
    project_id = var.project_id
  })

  service_account {
    email  = google_service_account.jenkins_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["jenkins", "http-server", "https-server"]
}

# SonarQube VM Instance
resource "google_compute_instance" "sonarqube" {
  name         = "sonarqube-server"
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = file("${path.module}/scripts/sonarqube-setup.sh")

  tags = ["sonarqube", "http-server"]
}

# Service Account for Jenkins
resource "google_service_account" "jenkins_sa" {
  account_id   = "jenkins-sa"
  display_name = "Jenkins Service Account"
}

# IAM roles for Jenkins
resource "google_project_iam_member" "jenkins_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

resource "google_project_iam_member" "jenkins_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

resource "google_project_iam_member" "jenkins_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

resource "google_project_iam_member" "jenkins_source_repo_admin" {
  project = var.project_id
  role    = "roles/source.admin"
  member  = "serviceAccount:${google_service_account.jenkins_sa.email}"
}

# Firewall rules
resource "google_compute_firewall" "jenkins" {
  name    = "jenkins-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080", "50000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

resource "google_compute_firewall" "sonarqube" {
  name    = "sonarqube-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sonarqube"]
}

# Static IP for Load Balancer
resource "google_compute_global_address" "default" {
  name = "${var.cluster_name}-ip"
}

# Create GCS bucket for storing artifacts
resource "google_storage_bucket" "artifacts" {
  name     = "${var.project_id}-${var.cluster_name}-artifacts"
  location = var.region
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
}

# Note: Cloud Build triggers are commented out as they require manual GitHub App setup
# You can create these manually in the Google Cloud Console after setting up GitHub integration

# # Cloud Build triggers
# resource "google_cloudbuild_trigger" "backend_trigger" {
#   name = "backend-build-trigger"
#
#   github {
#     owner = var.github_owner
#     name  = var.github_repo
#     push {
#       branch = "^main$"
#     }
#   }
#
#   build {
#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = [
#         "build",
#         "-t", "gcr.io/${var.project_id}/placement-backend:$COMMIT_SHA",
#         "-f", "backend/Dockerfile",
#         "backend/"
#       ]
#     }
#
#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = ["push", "gcr.io/${var.project_id}/placement-backend:$COMMIT_SHA"]
#     }
#
#     step {
#       name = "gcr.io/cloud-builders/gke-deploy"
#       args = [
#         "run",
#         "--filename=k8s/backend-deployment.yaml",
#         "--image=gcr.io/${var.project_id}/placement-backend:$COMMIT_SHA",
#         "--cluster=${google_container_cluster.placement_cluster.name}",
#         "--location=${var.zone}"
#       ]
#     }
#   }
# }
#
# resource "google_cloudbuild_trigger" "frontend_trigger" {
#   name = "frontend-build-trigger"
#
#   github {
#     owner = var.github_owner
#     name  = var.github_repo
#     push {
#       branch = "^main$"
#     }
#   }
#
#   build {
#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = [
#         "build",
#         "-t", "gcr.io/${var.project_id}/placement-frontend:$COMMIT_SHA",
#         "-f", "frontend/Dockerfile",
#         "frontend/"
#       ]
#     }
#
#     step {
#       name = "gcr.io/cloud-builders/docker"
#       args = ["push", "gcr.io/${var.project_id}/placement-frontend:$COMMIT_SHA"]
#     }
#
#     step {
#       name = "gcr.io/cloud-builders/gke-deploy"
#       args = [
#         "run",
#         "--filename=k8s/frontend-deployment.yaml",
#         "--image=gcr.io/${var.project_id}/placement-frontend:$COMMIT_SHA",
#         "--cluster=${google_container_cluster.placement_cluster.name}",
#         "--location=${var.zone}"
#       ]
#     }
#   }
# }
