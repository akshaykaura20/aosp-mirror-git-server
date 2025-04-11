locals {
  http_traffic = {
    protocol  = "HTTP"
    port      = "80"
    port_name = "http-port"
  }
  https_traffic = {
    protocol  = "HTTPS"
    port      = "443"
    port_name = "https-port"
  }

  backend_service_timeout_sec = 30

  health_check = {
    path               = "/health"
    check_interval_sec = 5
    timeout_sec        = 5
  }
}