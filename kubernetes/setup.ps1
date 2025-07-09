$NAMESPACE = "smart-home"
$TIMEOUT = 120

Write-Host "Starting Minikube..."
minikube start --driver=docker --memory=4096 --cpus=2

Write-Host "Enabling ingress addon..."
minikube addons enable ingress

Write-Host "Opening tunnel to ingress controller..."
Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoExit", "-Command", "minikube tunnel *> minikube-tunnel.log"

Write-Host "Applying LoadBalancer and Ingress..."
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-dashboard-svc.yaml

Write-Host "Waiting for Minikube tunnel to assign LoadBalancer IP..."

$success = $false
for ($i = 0; $i -lt 30; $i++) {
    $services = kubectl get svc --all-namespaces
    if ($services -match "LoadBalancer") {
        Write-Host "Minikube tunnel is active."
        $success = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $success) {
    Write-Error "Tunnel did not become active. Exiting."
    exit 1
}

Write-Host "Applying backend Kubernetes manifests in order..."
kubectl apply -f 02-mongo-secrets.yaml
kubectl apply -f 03-backend-cm.yaml
kubectl apply -f 04-backend-manifest.yaml

Write-Host "Waiting for all backend pods in '$NAMESPACE' to be ready..."
$podsReady = kubectl wait --namespace $NAMESPACE --for=condition=ready pod --all --timeout="${TIMEOUT}s" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Timeout or error waiting for pods to become ready:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Host "All backend pods are ready. Proceeding..."
}

Write-Host "Applying all manifests in the current directory..."
kubectl apply -f .

Write-Host "Waiting for the rest of the pods in '$NAMESPACE' to be ready..."
$podsReady = kubectl wait --namespace $NAMESPACE --for=condition=ready pod --all --timeout="${TIMEOUT}s" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Timeout or error waiting for pods readiness:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Host "All pods in '$NAMESPACE' are ready."
}

$externalIp = kubectl get svc smart-home-dashboard-svc -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
if ([string]::IsNullOrEmpty($externalIp)) {
    Write-Host "LoadBalancer external IP not assigned yet"
}
else {
    Write-Host "External IP: $externalIp"
}

Write-Host "`n*** Done! ***`n"
