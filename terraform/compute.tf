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

  network_interface {
    network    = google_compute_network.mirror_vpc.id
    subnetwork = google_compute_subnetwork.mirror_subnet.id
  }

  # Install Apache & Git Automatically on Startup
  metadata_startup_script = <<EOT
    #!/bin/bash
    sudo apt update && sudo apt install -y apache2 git
    sudo systemctl enable --now apache2
    echo "Git Mirror is Ready!" | sudo tee /var/www/html/index.html
    echo "Healthy" | sudo tee /var/www/html/health
  EOT
}