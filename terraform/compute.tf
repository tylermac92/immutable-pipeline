# ==============================================================================
# Instance Template, MIG, and Autoscaler
# ==============================================================================

resource "google_compute_instance_template" "app" {
  name_prefix = "app-template-"
  machine_type = var.machine_type

  disk {
    source_image = var.image_name
    disk_type = "pd-ssd"
    disk_size_gb = 20
    auto_delete = true
    boot = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_a.id
  }

  service_account {
    email = var.sa_instance_runtime_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "true"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = ["http-server"]
}

resource "google_compute_region_instance_group_manager" "app_mig" {
  name = "app-regional-mig"
  base_instance_name = "app-mig-instance"
  region = var.region

  distribution_policy_zones = [
    var.zone_a,
    var.zone_b
  ]

  version {
    instance_template = google_compute_instance_template.app.id
  }

  named_port {
    name = "http"
    port = var.named_port
  }

  auto_healing_policies {
    health_check = google_compute_health_check.app_hc.id
    initial_delay_sec = 300
  }

  update_policy {
    type = "PROACTIVE"
    minimal_action = "REPLACE"
    max_surge_fixed = 2
    max_unavailable_fixed = 0
  }
}

resource "google_compute_health_check" "app_hc" {
  name = "app-http-hc"
  check_interval_sec = 10
  timeout_sec = 5
  healthy_threshold = 2
  unhealthy_threshold = 3

  http_health_check {
    port = 80
    request_path = "/"
  }
}

resource "google_compute_region_autoscaler" "app_autoscaler" {
  name = "app-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.app_mig.id

  autoscaling_policy {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    cpu_utilization {
      target = 0.6
    }
  }
}
