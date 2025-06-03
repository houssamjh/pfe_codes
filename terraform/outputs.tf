# --------------------------------------------------------
# Sorties utiles après déploiement Terraform
# --------------------------------------------------------

# IP publique de la VM Kali
output "kali_public_ip" {
  description = "Adresse IP publique de la VM Kali Linux"
  value       = google_compute_instance.kali.network_interface[0].access_config[0].nat_ip
}

# Nom du cluster GKE
output "gke_cluster_name" {
  description = "Nom du cluster Kubernetes GKE"
  value       = google_container_cluster.gke.name
}

# Endpoint du cluster GKE 
output "gke_endpoint" {
  description = "Adresse du endpoint API server de GKE"
  value       = google_container_cluster.gke.endpoint
}

output "ingress_ip" {
  description = "Adresse IP statique utilisée par le Load Balancer Ingress"
  value       = google_compute_address.ingress_ip.address
}


