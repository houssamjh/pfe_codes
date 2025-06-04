Set-Location "./terraform"

Write-Host "[INFO] Initialisation du backend Terraform..." -ForegroundColor Cyan
terraform init -reconfigure

if ($LASTEXITCODE -ne 0) {
    Write-Error "[ERREUR] terraform init a échoué. Abandon du script."
    exit 1
}

Write-Host "`n[INFO] Début de la destruction ciblée des ressources..." -ForegroundColor Yellow

terraform destroy -auto-approve \
  -target="google_project_iam_member.gke_sa_cluster_admin" \
  -target="google_project_iam_member.gke_logging" \
  -target="google_project_iam_member.gke_monitoring_viewer" \
  -target="google_project_iam_member.gke_logging_viewer" \
  -target="google_project_iam_member.gke_storage_admin" \
  -target="google_project_iam_member.gke_compute_network_admin" \
  -target="google_project_iam_member.gke_serviceusage_admin" \
  -target="google_compute_network.vpc" \
  -target="google_compute_subnetwork.subnet" \
  -target="google_compute_router.nat_router" \
  -target="google_compute_router_nat.nat" \
  -target="google_compute_firewall.allow_ssh_to_kali" \
  -target="google_compute_firewall.allow_lb_to_apps" \
  -target="google_compute_firewall.allow_kali_to_apps" \
  -target="google_compute_instance.kali" \
  -target="google_container_cluster.gke" \
  -target="google_container_node_pool.primary_nodes"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Terraform a échoué avec le code : $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}


Write-Host "`n✅ Destruction terminée avec succès !" -ForegroundColor Green
