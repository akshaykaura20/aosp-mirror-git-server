# Enable Secret Manager API
resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "gh_repo_pat_secret" {
  secret_id = "GH_REPO_PAT"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gh_repo_pat_secret_version" {
  secret      = google_secret_manager_secret.gh_repo_pat_secret.id
  secret_data = var.gh_repo_pat
}

resource "google_secret_manager_secret" "mirror_git_server_password_secret" {
  secret_id = "GIT_SERVER_PASSWORD"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mirror_git_server_password_secret_version" {
  secret      = google_secret_manager_secret.mirror_git_server_password_secret.id
  secret_data = var.mirror_git_server_password
}
