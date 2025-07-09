Write-Host "Starting Minikube..."
minikube start

Write-Host "Enabling ingress addon..."
minikube addons enable ingress

# Write-Host "Opening tunnel to ingress controller..."
# Start-Process powershell -ArgumentList "-NoExit", "-Command", "minikube tunnel"

Write-Host "Waiting for ingress-nginx controller and webhook to be ready..."

$ingressReady = kubectl wait --namespace ingress-nginx --for=condition=available deployment ingress-nginx-controller --timeout=120s 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Ingress controller not ready: $ingressReady"
    exit 1
}

Write-Host "Ingress controller is ready. Applying manifests..."
kubectl apply -f .

# Get Minikube IP
$minikubeIp = minikube ip 2>$null
if (-not $minikubeIp) {
    Write-Error "Failed to get Minikube IP. Is Minikube running?"
    exit 1
}

Write-Output "Waiting for all pods in 'smart-home' namespace to be ready..."
$podsReady = kubectl wait --namespace smart-home --for=condition=ready pod --all --timeout=120s 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Timeout or error waiting for pods readiness:"
    Write-Output $podsReady
    exit 1
}
else {
    Write-Output "All pods in 'smart-home' are ready."
}

$externalIp = kubectl get svc smart-home-dashboard-svc -n smart-home -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
if ([string]::IsNullOrEmpty($externalIp)) {
    Write-Host "LoadBalancer external IP not assigned yet"
}
else {
    Write-Host "External IP: $externalIp"
}

Write-Host "*** Done! ***"
