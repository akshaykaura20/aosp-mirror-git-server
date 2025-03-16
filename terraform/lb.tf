# We follow a top-down approach. 
# Traffic enters each defined resource in the order they are defined here.

#############################
# Load Balancer Configuration
#############################

# Todo: DNS
# DNS maps our domain name to load balancer's IP addresses.

# Reserve a Static Public IP for Load Balancer
resource "google_compute_global_address" "mirror_lb_public_ip" {
  name = "mirror-lb-public-ip"
}

# Create a Global Forwarding Rule for Load Balancer
# Routes incoming traffic to the correct target HTTP proxy
resource "google_compute_global_forwarding_rule" "mirror_forwarding_rule" {
  name       = "mirror-forwarding-rule"
  target     = google_compute_target_http_proxy.mirror_http_proxy.id
  port_range = local.http_traffic.port
  ip_address = google_compute_global_address.mirror_lb_public_ip.address
}

# Create a Target HTTP Proxy for Load Balancer
# Decrypts traffic data with SSL certificates and forwards it to the correct URL Map
resource "google_compute_target_http_proxy" "mirror_http_proxy" {
  name    = "mirror-http-proxy"
  url_map = google_compute_url_map.mirror_url_map.id
}

# Create a URL Map for Load Balancer
# Routes traffic to correct backend service (path)
resource "google_compute_url_map" "mirror_url_map" {
  name            = "mirror-url-map"
  default_service = google_compute_backend_service.mirror_lb_backend_service.id
}

# Create a backend service for Load Balancer
resource "google_compute_backend_service" "mirror_lb_backend_service" {
  name                  = "git-server-backend"
  protocol              = local.http_traffic.protocol # change it to HTTPS for SSL
  port_name             = google_compute_instance_group.mirror_lb_instance_group.named_port[0].name
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = local.backend_service_timeout_sec
  health_checks         = [google_compute_health_check.default.self_link]

  backend {
    group = google_compute_instance_group.mirror_lb_instance_group.self_link # Points to the VM
  }
}
# Create a Health Check for Load Balancer (HTTP)
# Checks if the VM is healthy and can accept traffic
resource "google_compute_health_check" "default" {
  name               = "git-server-health-check"
  check_interval_sec = local.health_check.check_interval_sec
  timeout_sec        = local.health_check.timeout_sec

  http_health_check {
    port         = local.http_traffic.port
    request_path = local.health_check.path
  }
}

# Create a unmanaged instance group for the VM
# LB's backend-service will route requests to this group
resource "google_compute_instance_group" "mirror_lb_instance_group" {
  name        = "mirror-lb-instance-group"
  zone        = "${var.region}-a"
  description = "Instance Group for Git Mirror VM"
  instances   = [google_compute_instance.mirror_vm.id]

  named_port {
    name = local.http_traffic.port_name 
    port = local.http_traffic.port # change it to 443 for HTTPS (SSL)
  }

  depends_on = [google_compute_instance.mirror_vm] # Ensures VM exists first
}