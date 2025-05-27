# --------------------------------------------------------
# Provider
# --------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# --------------------------------------------------------
# VPC Network
# --------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "pfe-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "pfe-subnet"
  ip_cidr_range = "10.10.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# --------------------------------------------------------
# NAT Configuration
# --------------------------------------------------------
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# --------------------------------------------------------
# Firewall Rules
# --------------------------------------------------------
resource "google_compute_firewall" "allow_kali_to_apps" {
  name    = "fw-allow-kali-to-apps"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30070", "30080", "30090"]
  }

  source_ranges = ["197.230.162.92/32", "10.10.10.5/32"]
  direction     = "INGRESS"
  target_tags   = ["apps"]
}

resource "google_compute_firewall" "allow_ssh_to_kali" {
  name    = "fw-allow-ssh-kali"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.test_ip]
  target_tags   = ["kali"]
}

resource "google_compute_firewall" "allow_lb_to_apps" {
  name    = "fw-allow-lb-to-apps"
  network = google_compute_network.vpc.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["apps"]
}

# --------------------------------------------------------
# Compute Instance - Kali
# --------------------------------------------------------
resource "google_compute_instance" "kali" {
  name         = "kali-linux"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "kali-ready"
      type  = "pd-ssd" # disque performant
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name
    network_ip = "10.10.10.5"

    access_config {}
  }

  tags = ["kali"]
}

# --------------------------------------------------------
# GKE Cluster
# --------------------------------------------------------
resource "google_container_cluster" "gke" {
  name       = "vuln-cluster"
  location   = var.zone
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "default-node-pool"
  cluster  = google_container_cluster.gke.name
  location = var.zone

  node_config {
    machine_type = "e2-medium"
    tags         = ["apps"]
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    service_account = var.gke_sa_email
  }

  initial_node_count = 3
}


# --------------------------------------------------------
# Artifact Registry
# --------------------------------------------------------
#resource "google_artifact_registry_repository" "docker_repo" {
#  location      = var.region
#  repository_id = "pfe-docker-repo"
#  format        = "DOCKER"
#  description   = "Repository for OWASP vulnerable Docker images"
#}

# --------------------------------------------------------
# Activer les APIs automatiquement
# --------------------------------------------------------
resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"
}

# --------------------------------------------------------
# IAM Bindings
# --------------------------------------------------------
# permet de donné  au github des permission pour le deploiement
resource "google_project_iam_member" "gke_sa_cluster_admin" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
}

# Permet à GKE d'écrire des logs dans Cloud Logging
resource "google_project_iam_member" "gke_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = format("serviceAccount:%s", var.gke_sa_email)
}

# Permet à GKE de pousser des images dans Artifact Registry
#resource "google_project_iam_member" "gke_artifact_writer" {
#  project = var.project_id
#  role    = "roles/artifactregistry.writer"
#  member = format("serviceAccount:%s", var.gke_sa_email)
#}

# Permet au cluster GKE de consulter les métriques dans Cloud Monitoring
resource "google_project_iam_member" "gke_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = format("serviceAccount:%s", var.gke_sa_email)
}

# Permet au cluster GKE de lire les logs dans Cloud Logging
resource "google_project_iam_member" "gke_logging_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = format("serviceAccount:%s", var.gke_sa_email)
}
# Donne accès au backend Terraform (bucket GCS)
resource "google_project_iam_member" "gke_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
}

# Pour créer VPC, subnet, firewall, etc.
resource "google_project_iam_member" "gke_compute_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkViewer"
  member  = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
}

# Pour gérer Artifact Registry (create repository)
#resource "google_project_iam_member" "gke_artifact_admin" {
# project = var.project_id
#role    = "roles/artifactregistry.admin"
#member = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
#}

# Pour créer les alertes / channels de monitoring
resource "google_project_iam_member" "gke_monitoring_editor" {
  project = var.project_id
  role    = "roles/monitoring.editor"
  member  = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
}

# Pour permettre à Terraform d’activer les APIs automatiquement
resource "google_project_iam_member" "gke_serviceusage_admin" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = format("serviceAccount:gke-service-account@%s.iam.gserviceaccount.com", var.project_id)
}

# --------------------------------------------------------
# alerte CPU
# --------------------------------------------------------
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "Alertes CPU Pods"
  type         = "email"

  labels = {
    email_address = "houssam.jihaze@gmail.com"
  }
}

resource "google_monitoring_alert_policy" "high_cpu_pods" {
  display_name = "CPU élevé pour tous les pods"

  combiner = "OR"
  conditions {
    display_name = "CPU > 80% sur tous les pods"
    condition_threshold {
      filter          = <<EOT
resource.type="k8s_container"
AND metric.type = "kubernetes.io/container/cpu/request_utilization"
EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_channel.id]

  documentation {
    content   = "Attention: un ou plusieurs pods consomment > 80% de CPU."
    mime_type = "text/markdown"
  }

  enabled = true
}


# --------------------------------------------------------
# IP statique pour Ingress
# --------------------------------------------------------
resource "google_compute_address" "ingress_ip" {
  name   = "ingress-ip"
  region = var.region

  lifecycle {
    prevent_destroy = true
  }
}

# --------------------------------------------------------
# Cloud DNS
# --------------------------------------------------------
resource "google_dns_managed_zone" "jhous_zone" {
  name        = "jhous-zone"
  dns_name    = "jhous.me."
  description = "Zone DNS pour le domaine jhous.me"
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_dns_record_set" "dvwa" {
  name         = "dvwa.jhous.me."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.jhous_zone.name
  rrdatas      = [google_compute_address.ingress_ip.address]
}

resource "google_dns_record_set" "juice" {
  name         = "juice.jhous.me."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.jhous_zone.name
  rrdatas      = [google_compute_address.ingress_ip.address]
}

resource "google_dns_record_set" "webgoat" {
  name         = "webgoat.jhous.me."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.jhous_zone.name
  rrdatas      = [google_compute_address.ingress_ip.address]
}


