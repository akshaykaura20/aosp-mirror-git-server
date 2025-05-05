locals {
  zone = "${var.region}-b"
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
    check_interval_sec   = 40 # check every 40s
    timeout_sec          = 10 # wait for 10s for response
    healthy_threshold    = 3  # declare healthy after
    unhealthy_threshold  = 10 # max retries
  } # total time = (40 + 10) * 10 = 500s
}