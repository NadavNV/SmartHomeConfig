# Variables
$hostname = "smart-home-dashboard.local"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$timeoutSeconds = 120
$startTime = Get-Date

# Start Minikube
Write-Host "Starting Minikube..."
minikube start

# Enable ingress addon
Write-Host "Enabling ingress addon..."
minikube addons enable ingress

# Apply YAML manifests in current directory
Write-Host "Applying Kubernetes manifests..."
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


# Update hosts file
$hostsContent = Get-Content -Path $hostsPath
$filteredContent = $hostsContent | Where-Object { $_ -notmatch "$hostname" }
$newEntry = "$minikubeIp `t $hostname"
Set-Content -Path $hostsPath -Value ($filteredContent + $newEntry) -Force
Write-Host "Updated hosts file: $newEntry"

# Wait for ingress to become available
Write-Host "Waiting for ingress to be ready..."

while ($true) {
    $response = try {
        Invoke-WebRequest -Uri "http://$hostname" -UseBasicParsing -TimeoutSec 5
    }
    catch {
        $null
    }

    if ($response -and $response.StatusCode -eq 200) {
        Write-Host "Ingress is up and serving traffic!"
        break
    }

    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -gt $timeoutSeconds) {
        Write-Warning "Timeout waiting for ingress. Exiting."
        break
    }

    Start-Sleep -Seconds 5
}
