variable "backend_bucket_name" {
  description = "GCS bucket to store terraform state"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
  # default     = "qwiklabs-gcp-03-05805bd2d501" prj-s-agbg-gcp-sdv-prod
}

variable "region" {
  description = "GCP region to deploy to"
  type        = string
  # default     = "us-central1"
}

variable "gh_repo" {
  description = "Link to this repo used for cloning in scripts"
  type        = string
  default     = ""
}

variable "gh_repo_pat" {
  description = "GitHub Personal Access Token used for cloning repo in scripts"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mirror_git_server_password" {
  description = "Password for writing to the Git server"
  type        = string
  sensitive   = true
  default     = ""
}