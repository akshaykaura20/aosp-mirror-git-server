provider "google" {
  project     = var.project_id             # Project where resources will be deployed
  region      = var.region                 # Default region
  credentials = file(var.credentials_file) # Path to GCP service account key
}