# Output key values
output "lb_static_ip" {
  value = google_compute_global_address.mirror_lb_public_ip.address
  description = "Static IP for Load Balancer"
}