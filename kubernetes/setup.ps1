param (
    [switch]$skip
)

$NAMESPACE = "smart-home"
$TIMEOUT = 120

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

Write-Host "Applying LoadBalancer and Ingress..." -ForegroundColor Cyan
kubectl apply -f 00-namespace.yaml
kubectl apply -f 02-dashboard-svc.yaml

Write-Host "Waiting for Minikube tunnel to assign LoadBalancer IP..." -ForegroundColor Yellow

Start-Sleep -Seconds 2

$success = $false
for ($i = 0; $i -lt 30; $i++) {
    $ingressPods = kubectl get pods -n ingress-nginx --no-headers | Select-String "Running"
    if ($ingressPods) {
        Write-Host "Minikube tunnel is active." -ForegroundColor Green
        $success = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $success) {
    Write-Error "Tunnel did not become active. Exiting."
    exit 1
}

Write-Host "Applying MQTT deployment..." -ForegroundColor Cyan
kubectl apply -f 01-mqtt-manifest.yaml

Write-Host "Waiting for MQTT broker pod in '$NAMESPACE' to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$podsReady = kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Timeout or error waiting for pod to become ready:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Host "MQTT broker is ready. Proceeding..." -ForegroundColor Green
}

Write-Host "Applying backend Kubernetes manifests in order..." -ForegroundColor Cyan
kubectl apply -f 03-secrets.yaml
kubectl apply -f 05-backend-cm.yaml
kubectl apply -f 06-backend-manifest.yaml

Write-Host "Waiting for all backend pods in '$NAMESPACE' to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$podsReady = kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Timeout or error waiting for pods to become ready:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Host "All backend pods are ready. Proceeding..." -ForegroundColor Green
}

Write-Host "Applying all manifests in the current directory..." -ForegroundColor Cyan
kubectl apply -f .

Write-Host "Waiting for the rest of the pods in '$NAMESPACE' to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$deployReady = kubectl wait --namespace $NAMESPACE --for=condition=available deployment --all --timeout="${TIMEOUT}s" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Timeout or error waiting for deployment to become ready:"
    Write-Output $deployReady
    exit 1
}
$podsReady = kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Timeout or error waiting for pods readiness:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Host "All pods in '$NAMESPACE' are ready." -ForegroundColor Green
}

Write-Host "Adding DNS names to hosts file..." -ForegroundColor Cyan
$hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
$entries = @(
    "127.0.0.1 dashboard.local"
    "127.0.0.1 grafana.local"
)

foreach ($entry in $entries) {
    if (-not (Select-String -Path $hostsPath -Pattern $entry -Quiet)) {
        Add-Content -Path $hostsPath -Value $entry
        Write-Host "Added $entry to hosts file" -ForegroundColor Green
    }
    else {
        Write-Host "$entry already exists in hosts file" -ForegroundColor Yellow
    }
}

Write-Host "Frontend: http://dashboard.local" -ForegroundColor Cyan
Write-Host "Grafana: http://grafana.local" -ForegroundColor Cyan

Write-Host "Installing Argo CD..." -ForegroundColor Cyan

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Write-Host "Waiting for Argo CD server pod to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$argoReady = kubectl wait --namespace argocd --for=condition=Ready pods --selector app.kubernetes.io/name=argocd-server --timeout="${TIMEOUT}s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Argo CD server pod did not become ready."
    Write-Host $argoReady
    exit 1
}

Write-Host "Exposing Argo CD with Ingress..." -ForegroundColor Cyan
kubectl apply -f ../argocd/argocd-ingress.yaml

Write-Host "Adding Argo CD domain to hosts file..." -ForegroundColor Cyan
$entry = "127.0.0.1 argocd.local"
if (-not (Select-String -Path $hostsPath -Pattern $entry -Quiet)) {
    Add-Content -Path $hostsPath -Value $entry
    Write-Host "Added $entry to hosts file" -ForegroundColor Green
}
else {
    Write-Host "$entry already exists in hosts file" -ForegroundColor Yellow
}
Write-Host "Argo CD UI: https://argocd.local" -ForegroundColor Cyan

Write-Host "Bootstrapping Argo CD application..." -ForegroundColor Cyan
kubectl apply -f ../argocd/app.yaml -n argocd

Write-Host "`n*** Done! ***`n" -ForegroundColor Green

