#############################
# VM Configuration 
#############################

# Create a Compute Instance for Git Mirror
resource "google_compute_instance" "mirror_vm" {
  name         = "mirror-git-server"
  machine_type = "n1-standard-16" # 16 vCPUs, 60GB RAM
  zone         = "${var.region}-a"

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

  metadata_startup_script = templatefile("${path.module}/../scripts/vm-init.sh", {
    gh_repo = "${var.gh_repo}",
    lb_static_ip = google_compute_global_address.mirror_lb_public_ip.address
  })
}

# Provide the access to read secrets for the SA used by Compute Instance
resource "google_project_iam_member" "allow_mirror_vm_to_read_secrets" {
  project = var.project_id
  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:sdv-public-aosp-mirror-git-sa@${var.project_id}.iam.gserviceaccount.com"
}
