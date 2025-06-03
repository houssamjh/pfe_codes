# --------------------------------------------------------
# Variables pour le projet GCP et l'infrastructure
# --------------------------------------------------------

variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP à utiliser"
  type        = string
  default     = "europe-xxx"
}

variable "zone" {
  description = "Zone GCP à utiliser"
  type        = string
  default     = "europe-xxx"
}

variable "test_ip" {
  description = "Adresse IP publique autorisée à accéder en SSH à Kali"
  type        = string
}

variable "gke_sa_email" {
  description = "Email du compte de service par défaut généré par GKE"
  type        = string
}