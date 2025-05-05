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

# Create a GCP managed SSL certificate to enable https
resource "google_compute_managed_ssl_certificate" "mirror_lb_ssl_cert" {
  name = "mirror-lb-ssl-cert"
  managed {
    domains = ["mirror.horizon-sdv.com"]
  }
}

# Create a Global HTTPS (443) Forwarding Rule for Load Balancer
# Routes incoming traffic to the correct target HTTPS (443) proxy
resource "google_compute_global_forwarding_rule" "mirror_https_forwarding_rule" {
  name       = "mirror-https-forwarding-rule"
  target     = google_compute_target_https_proxy.mirror_https_proxy.id
  port_range = local.https_traffic.port
  ip_address = google_compute_global_address.mirror_lb_public_ip.address
}

# Create a Target HTTPS (443) Proxy for Load Balancer
# Decrypts traffic data with SSL certificates and forwards it to the correct URL Map
resource "google_compute_target_https_proxy" "mirror_https_proxy" {
  name    = "mirror-https-proxy"
  url_map = google_compute_url_map.mirror_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.mirror_lb_ssl_cert.id]
}

# Create a Global HTTP (80) Forwarding Rule for Load Balancer
# Routes incoming traffic to the correct target HTTP (80) proxy
resource "google_compute_global_forwarding_rule" "mirror_http_forwarding_rule" {
  name       = "mirror-http-forwarding-rule"
  target     = google_compute_target_http_proxy.mirror_http_proxy.id
  port_range = local.http_traffic.port
  ip_address = google_compute_global_address.mirror_lb_public_ip.address
}

# Create a Target HTTP (80) Proxy for Load Balancer
# Forwards traffic data to the correct URL Map
resource "google_compute_target_http_proxy" "mirror_http_proxy" {
  name    = "mirror-http-proxy"
  url_map = google_compute_url_map.mirror_redirect_http_to_https_url_map.id
}

# Create a URL Map for Load Balancer (HTTPS 443)
# Routes traffic to correct backend service (path)
resource "google_compute_url_map" "mirror_url_map" {
  name            = "mirror-url-map"
  default_service = google_compute_backend_service.mirror_lb_backend_service.id
}
# Create a URL Map for Load Balancer for redirect of HTTP (80) traffic to HTTPS proxy
resource "google_compute_url_map" "mirror_redirect_http_to_https_url_map" {
  name            = "mirror-redirect-http-to-https-url-map"

  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}

# Create a backend service for Load Balancer
resource "google_compute_backend_service" "mirror_lb_backend_service" {
  name                  = "git-server-backend"
  protocol              = local.http_traffic.protocol
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
  healthy_threshold  = local.health_check.healthy_threshold
  unhealthy_threshold = local.health_check.unhealthy_threshold

  http_health_check {
    port         = local.http_traffic.port
    request_path = local.health_check.path
  }
  log_config {
    enable = true
  }
}

# Create a unmanaged instance group for the VM
# LB's backend-service will route requests to this group
resource "google_compute_instance_group" "mirror_lb_instance_group" {
  name        = "mirror-lb-instance-group"
  zone        = local.zone
  description = "Instance Group for Git Mirror VM"
  instances   = [google_compute_instance.mirror_vm.self_link]

  named_port {
    name = local.http_traffic.port_name
    port = local.http_traffic.port # change it to 443 for HTTPS (SSL)
  }

  depends_on = [google_compute_instance.mirror_vm] # Ensures VM exists first
}