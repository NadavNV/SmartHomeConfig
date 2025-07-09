#!/bin/bash

HOSTNAME="smart-home-dashboard.local"
HOSTS_FILE="/etc/hosts"
TIMEOUT=120
START_TIME=$(date +%s)

echo "Starting Minikube..."
minikube start --driver=docker --memory=4096 --cpus=2

echo "Enabling ingress addon..."
minikube addons enable ingress

echo "Opening tunnel to ingress controller..."
nohup minikube tunnel > minikube-tunnel.log 2>&1 &

echo "Applying Kubernetes manifests..."
kubectl apply -f .

echo "Waiting for all pods in 'smart-home' namespace to be ready..."
podsReady=$(kubectl wait --namespace smart-home --for=condition=ready pod --all --timeout=120s 2>&1)

if [ $? -ne 0 ]; then
  echo "Timeout or error waiting for pods to become ready:"
  echo "$podsReady"
  exit 1
else
  echo "All pods in 'smart-home' are ready."
fi

echo "Waiting for Minikube tunnel to assign LoadBalancer IP..."

# Retry for up to 60 seconds
for i in {1..30}; do
    # Check if any LoadBalancer IP is assigned in any service in any namespace
    if kubectl get svc --all-namespaces | grep -q 'LoadBalancer'; then
        echo "Minikube tunnel is active."
        break
    fi
    sleep 2
done

# Final check: error out if tunnel failed
if ! kubectl get svc --all-namespaces | grep -q 'LoadBalancer'; then
    echo "Tunnel did not become active. Exiting."
    exit 1
fi

EXTERNAL_IP=$(kubectl get svc smart-home-dashboard-svc -n smart-home -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$EXTERNAL_IP" ]; then
  echo "LoadBalancer external IP not assigned yet"
else
  echo "External IP: $EXTERNAL_IP"
fi

echo "\n*** Done! ***\n"
