terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  # Option 1: Using a local key file (add to .gitignore)
  # credentials = file("gcp-key.json")
  
  # Option 2: Using environment variable (more secure)
  # Don't specify credentials here - set GOOGLE_APPLICATION_CREDENTIALS 
  # environment variable to point to your key file
}
