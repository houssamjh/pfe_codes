
Set-Location "./terraform"


Write-Host "`n[INFO] Récupération de l'adresse IP statique depuis Terraform..."
$STATIC_IP = terraform output -raw ingress_ip

if (-not $STATIC_IP) {
    Write-Host "`n[ERREUR] Impossible de récupérer l'adresse IP statique. Vérifiez Terraform."
    exit 1
}

Write-Host "[OK] IP statique obtenue : $STATIC_IP"


Set-Location ".."


Write-Host "`n[INFO] Installation du plugin gke-gcloud-auth-plugin (nécessaire pour kubectl avec GKE)..."
& gcloud components install gke-gcloud-auth-plugin --quiet


Write-Host "`n[INFO] Connexion au cluster GKE..."
gcloud container clusters get-credentials vuln-cluster --zone europe-xxx --project pfe-cloud-security



Write-Host "`n[INFO] Vérification du contexte Kubernetes..."
$maxTries = 10
$contextReady = $false

for ($i = 0; $i -lt $maxTries; $i++) {
    try {
        $context = kubectl config current-context 2>$null
        if ($context) {
            $contextReady = $true
            break
        }
    } catch {}
    Start-Sleep -Seconds 5
}

if (-not $contextReady) {
    Write-Host "`n[ERREUR] Le cluster Kubernetes n'est pas prêt."
    exit 1
}

Write-Host "`n[OK] Cluster prêt : $context"
kubectl get nodes


Write-Host "`n[INFO] Récupération des noms de nodes pour étiquetage..."
$nodes = & kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
$nodeArray = $nodes -split '\s+'

if ($nodeArray.Length -lt 3) {
    Write-Host "[ERREUR] Moins de 3 nodes trouvés. Impossible d'attribuer les rôles DVWA, JuiceShop, WebGoat."
    exit 1
}

$node1 = $nodeArray[0]
$node2 = $nodeArray[1]
$node3 = $nodeArray[2]

Write-Host "[OK] Nodes détectés :"
Write-Host " - Node 1 (DVWA)     : $node1"
Write-Host " - Node 2 (JuiceShop): $node2"
Write-Host " - Node 3 (WebGoat)  : $node3"


Write-Host "`n[INFO] Vérification de Helm..."
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] Helm n'est pas installé. Voir : https://helm.sh/docs/intro/install/"
    exit 1
}
helm version


Write-Host "`n[INFO] Ajout du repo NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update


Write-Host "`n[INFO] Installation du NGINX Ingress Controller avec IP statique..."
Write-Host "🧪 IP utilisée pour Helm : $STATIC_IP"

helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  --version 4.10.1 `
  "--set=controller.service.loadBalancerIP=$STATIC_IP" 


  Write-Host "`n[INFO] Attente de 30 secondes pour l'initialisation du Webhook Ingress NGINX..."
Start-Sleep -Seconds 30


$webhookReady = kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller-admission -o jsonpath="{.spec.ports[0].port}" 2>$null

if (-not $webhookReady) {
    Write-Host "`n[ERREUR] Le webhook d'admission Ingress NGINX n'est pas encore prêt. Veuillez réessayer plus tard."
    exit 1
}


Write-Host "`n[INFO] Déploiement des fichiers Kubernetes..."
kubectl apply -f k8s-manifests/ # f = filename

Write-Host "`n[INFO] État des ressources Kubernetes :"
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get nodes -o wide


Write-Host "`n[✅] IP statique utilisée : $STATIC_IP"
Write-Host "`n🌐 Accès aux applications via Ingress :"
Write-Host " - DVWA      -> http://dvwa.jhous.me"
Write-Host " - JuiceShop -> http://juice.jhous.me"
Write-Host " - WebGoat   -> http://webgoat.jhous.me"
