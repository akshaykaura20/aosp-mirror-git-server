#############################
# VPC and Subnet Configuration
#############################

# Create a VPC (compute network)
resource "google_compute_network" "mirror_vpc" {
  name                    = "mirror-vpc"
  auto_create_subnetworks = false  # we create our own subnet
}

# Create a Private Subnet in the VPC
resource "google_compute_subnetwork" "mirror_subnet" {
  name          = "mirror-subnet"
  network       = google_compute_network.mirror_vpc.id
  ip_cidr_range = "10.0.1.0/24"  # private IP range
  region        = var.region
}

#############################
# NAT Gateway Configuration
#############################

# Create a NAT Gateway (Allows Outbound Internet Access for Private VMs)
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  region  = var.region
  network = google_compute_network.mirror_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY" # automatically assigns a NAT IP
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

#############################
# Ingress Firewall Rules
#############################

# Allow HTTP/HTTPS Access (Git Server)
resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = google_compute_network.mirror_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]  # HTTP, HTTPS
  }

  source_ranges = ["0.0.0.0/0"]  # open to public
}

# Secure SSH Access (Only via IAP)
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.mirror_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # google's IAP range (secure access)
}