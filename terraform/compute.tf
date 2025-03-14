# We follow a bottom up approach

#############################
# VM Configuration 
#############################

# Create a Compute Instance for Git Mirror
resource "google_compute_instance" "mirror_vm" {
  name         = "mirror-git-server"
  machine_type = "n1-standard-16"  # 16 vCPUs, 60GB RAM
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10  # Disk size in GB
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
  EOT
}

#############################
# Load Balancer Configuration
#############################

# Create a unmanaged instance group for the VM
# The LB's backend-service will route requests to this group
resource "google_compute_instance_group" "mirror_lb_instance_group" {
  name        = "mirror-lb-instance-group"
  zone        = "${var.region}-a"
  description = "Instance Group for Git Mirror VM"
  instances   = [google_compute_instance.mirror_vm.id]
}

# Create a backend service for Load Balancer
resource "google_compute_backend_service" "mirror_lb_backend_service" {
  name        = "mirror-lb-backend-service"
  protocol    = "HTTP"
  timeout_sec = 30

  backend {
    group = google_compute_instance_group.mirror_lb_instance_group.self_link  # Points to the VM
  }
}

# Create a Health Check for Load Balancer (HTTP)
# Checks if the VM is healthy and can accept traffic
resource "google_compute_health_check" "default" {
  name               = "git-server-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    port = 80
    request_path = "/health"
  }
}

# Create a URL Map for Load Balancer
# Routes traffic to correct backend service (path)
resource "google_compute_url_map" "mirror_url_map" {
  name            = "mirror-url-map"
  default_service = google_compute_backend_service.mirror_lb_backend_service.id
}

# Create a Target HTTP Proxy for Load Balancer
# Proxy decrypts traffic data with SSL certificates and forwards it to the correct URL Map
resource "google_compute_target_http_proxy" "mirror_http_proxy" {
  name    = "mirror-http-proxy"
  url_map = google_compute_url_map.mirror_url_map.id
}

# Reserve a Static Public IP (for Load Balancer)
resource "google_compute_global_address" "mirror_lb_public_ip" {
  name = "mirror-lb-public-ip"
}

# Create a Global Forwarding Rule for Load Balancer
# Routes incoming traffic to the correct target HTTP proxy
resource "google_compute_global_forwarding_rule" "mirror_forwarding_rule" {
  name       = "mirror-forwarding-rule"
  target     = google_compute_target_http_proxy.mirror_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.mirror_lb_public_ip.address
}