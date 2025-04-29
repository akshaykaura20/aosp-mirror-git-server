# Output key values
output "lb_static_ip" {
  value       = google_compute_global_address.mirror_lb_public_ip.address
  description = "Static IP for Load Balancer"
}

output "lb_backend_service_name" {
  value       = google_compute_backend_service.mirror_lb_backend_service.name
  description = "The name of the Git server LB backend service."
}