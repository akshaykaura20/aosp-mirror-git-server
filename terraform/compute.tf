#############################
# VM Configuration 
#############################

# Create SA used by Compute Instance
resource "google_service_account" "vm_runtime_sa" {
  account_id   = "mirror-vm-runtime-sa"
  display_name = "SA for Mirror VM to access secrets"
}

# Provide the access to read secrets for the SA used by Compute Instance
resource "google_project_iam_member" "allow_vm_sa_secret_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vm_runtime_sa.email}"
}

# Create a Compute Instance for Git Mirror
resource "google_compute_instance" "mirror_vm" {
  name         = "mirror-git-server"
  machine_type = "n1-standard-16" # 16 vCPUs, 60GB RAM
  zone         = "${var.region}-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10 # Disk size in GB
    }
  }

  attached_disk {
    source = google_compute_disk.aosp_mirror_disk.id
    device_name = google_compute_disk.aosp_mirror_disk.name
  }

  network_interface {
    network    = google_compute_network.mirror_vpc.id
    subnetwork = google_compute_subnetwork.mirror_subnet.id
  }

  service_account {
    email  = google_service_account.vm_runtime_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/../scripts/setup.sh", {
    gh_repo = "${var.gh_repo}",
    lb_static_ip = google_compute_global_address.mirror_lb_public_ip.address
  })
}