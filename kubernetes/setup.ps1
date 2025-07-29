param (
    [switch]$skip
)

$TIMEOUT = 120
$ARGOCD_NAMESPACE = "argocd"
$HOSTS_PATH = "$env:WINDIR\System32\drivers\etc\hosts"

if (-not $skip) {
    Write-Host "Starting Minikube..." -ForegroundColor Cyan
    minikube start --driver=docker --memory=3072 --cpus=2

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Minikube failed to start. Exiting." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Skipping Minikube start as requested." -ForegroundColor Cyan
}

Write-Host "Enabling ingress addon..." -ForegroundColor Cyan
minikube addons enable ingress

Write-Host "Opening tunnel to ingress controller..." -ForegroundColor Cyan
Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoExit", "-Command", "minikube tunnel *> minikube-tunnel.log"

Write-Host "Waiting for ingress controller to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$success = $false
for ($i = 0; $i -lt 30; $i++) {
    $ingressPods = kubectl get pods -n ingress-nginx --no-headers | Select-String "Running"
    if ($ingressPods) {
        Write-Host "Ingress controller is ready." -ForegroundColor Green
        $success = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $success) {
    Write-Error "Ingress controller did not become ready. Exiting."
    exit 1
}

# --- Install Argo CD ---
Write-Host "Installing Argo CD..." -ForegroundColor Cyan
kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Write-Host "Waiting for Argo CD server pod to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$argoReady = kubectl wait --namespace $ARGOCD_NAMESPACE --for=condition=Ready pods --selector app.kubernetes.io/name=argocd-server --timeout="${TIMEOUT}s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Argo CD server pod did not become ready."
    Write-Host $argoReady
    exit 1
}

# --- Ingress for Argo CD UI ---
Write-Host "Exposing Argo CD with Ingress..." -ForegroundColor Cyan
kubectl apply -f ../argocd/argocd-ingress.yaml

$entry = "127.0.0.1 argocd.local"
if (-not (Select-String -Path $HOSTS_PATH -Pattern $entry -Quiet)) {
    Add-Content -Path $HOSTS_PATH -Value $entry
    Write-Host "Added $entry to hosts file" -ForegroundColor Green
}
else {
    Write-Host "$entry already exists in hosts file" -ForegroundColor Yellow
}
Write-Host "Argo CD UI: https://argocd.local" -ForegroundColor Cyan

# --- Bootstrap Argo CD applications ---
Write-Host "Bootstrapping Argo CD applications..." -ForegroundColor Cyan

# Apply all Argo CD App manifests
$argocdApps = @(
    "../argocd/setup_app.yaml",
    "../argocd/backend_app.yaml",
    "../argocd/frontend_app.yaml",
    "../argocd/simulator_app.yaml",
    "../argocd/monitoring_app.yaml"
)
foreach ($app in $argocdApps) {
    Write-Host "Applying Argo CD app: $app" -ForegroundColor Cyan
    kubectl apply -f $app -n $ARGOCD_NAMESPACE
}

# --- DNS entries for apps exposed via Ingress ---
$entries = @(
    "127.0.0.1 dashboard.local",
    "127.0.0.1 grafana.local"
)
foreach ($entry in $entries) {
    if (-not (Select-String -Path $HOSTS_PATH -Pattern $entry -Quiet)) {
        Add-Content -Path $HOSTS_PATH -Value $entry
        Write-Host "Added $entry to hosts file" -ForegroundColor Green
    }
    else {
        Write-Host "$entry already exists in hosts file" -ForegroundColor Yellow
    }
}

Write-Host "Frontend: http://dashboard.local" -ForegroundColor Cyan
Write-Host "Grafana: http://grafana.local" -ForegroundColor Cyan

Write-Host "`n*** Done! Argo CD is syncing your app manifests. ***`n" -ForegroundColor Green
