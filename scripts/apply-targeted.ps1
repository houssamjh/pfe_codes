Set-Location "./terraform"
#Set-Location "$PSScriptRoot\..\terraform"

Write-Host "[INFO] Initialisation du backend Terraform..." -ForegroundColor Cyan
terraform init -reconfigure
if ($LASTEXITCODE -ne 0) {
    Write-Error "[ERREUR] Échec de terraform init. Abandon du script."
    exit 1
}

Write-Host "[INFO] Début de l'application ciblée des ressources..." -ForegroundColor Cyan

terraform apply -auto-approve `
  -target="google_project_iam_member.gke_logging" `
  -target="google_project_iam_member.gke_artifact_writer" `
  -target="google_project_iam_member.gke_sa_cluster_admin" `
  -target="google_project_iam_member.gke_storage_admin" `
  -target="google_project_iam_member.gke_compute_network_admin" `
  -target="google_project_iam_member.gke_artifact_admin" `
  -target="google_project_iam_member.gke_monitoring_editor" `
  -target="google_project_iam_member.gke_serviceusage_admin" `
  -target="google_compute_network.vpc" `
  -target="google_compute_subnetwork.subnet" `
  -target="google_compute_router.nat_router" `
  -target="google_compute_router_nat.nat" `
  -target="google_compute_firewall.allow_ssh_to_kali" `
  -target="google_compute_firewall.allow_lb_to_apps" `
  -target="google_compute_firewall.allow_kali_to_apps" `
  -target="google_compute_instance.kali" `
  -target="google_container_cluster.gke" `
  -target="google_container_node_pool.primary_nodes" `
  -target="google_artifact_registry_repository.docker_repo" `
  -target="google_monitoring_notification_channel.email_channel" `
  -target="google_monitoring_alert_policy.high_cpu_pods"

if ($LASTEXITCODE -ne 0) {
    Write-Error "[ERREUR] terraform apply a échoué."
    exit 1
}

Write-Host "[SUCCESS] Application terminée !" -ForegroundColor Green
