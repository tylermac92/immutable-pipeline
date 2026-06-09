output "load_balancer_ip" {
  description = "The external IP address of the HTTP load balancer"
  value       = google_compute_global_address.app_lb_ip.address
}

output "image_deployed" {
  description = "The image name currently deployed to the MIG"
  value       = var.image_name
}

output "mig_name" {
  description = "The name of the Managed Instance Group"
  value       = google_compute_region_instance_group_manager.app_mig.name
}
