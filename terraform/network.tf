# ==============================================================================
# VPC and Subnets
# ==============================================================================

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet_a" {
  name                     = "${var.network_name}-subnet-a"
  ip_cidr_range            = var.subnet_cidr_a
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet_b" {
  name                     = "${var.network_name}-subnet-b"
  ip_cidr_range            = var.subnet_cidr_b
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# ==============================================================================
# Cloud Router and NAT (Egress Only)
# ==============================================================================

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ==============================================================================
# Firewall Rules
# ==============================================================================

# Allows secure SSH access via Identity-Aware Proxy (IAP)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google-defined netblock for IAP secure tunneling
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["packer-build"]
}

# Allows GCP Load Balancer traffic to reach managed instances
resource "google_compute_firewall" "allow_lb_traffic" {
  name    = "${var.network_name}-allow-lb-traffic"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.named_port)]
  }

  # Official Google-owned ranges for internal load balancer health check probes
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["http-server"]
}
