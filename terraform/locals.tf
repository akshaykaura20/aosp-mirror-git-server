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
    path                 = "/healthcheck"
    check_interval_sec   = 30
    timeout_sec          = 10
    healthy_threshold    = 2
    unhealthy_threshold  = 14 # scripts take time to finish
  }
}