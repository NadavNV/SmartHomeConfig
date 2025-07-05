#!/bin/bash

HOSTNAME="smart-home-dashboard.local"
HOSTS_FILE="/etc/hosts"
TIMEOUT=120
START_TIME=$(date +%s)

echo "Starting Minikube..."
minikube start

echo "Enabling ingress addon..."
minikube addons enable ingress

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



MINIKUBE_IP=$(minikube ip 2>/dev/null)
if [ -z "$MINIKUBE_IP" ]; then
  echo "Failed to get Minikube IP. Is Minikube running?"
  exit 1
fi

# Update hosts file to include the host name used by the ingress
sudo sed -i.bak "/[[:space:]]$HOSTNAME$/d" $HOSTS_FILE
echo -e "$MINIKUBE_IP\t$HOSTNAME" | sudo tee -a $HOSTS_FILE > /dev/null
echo "Updated hosts file: $MINIKUBE_IP    $HOSTNAME"

echo "Waiting for ingress to be ready..."

while true; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$HOSTNAME || echo "000")
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  if [ "$HTTP_CODE" == "200" ]; then
    echo "Ingress is up and serving traffic!"
    break
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Timeout waiting for ingress. Exiting."
    exit 1
  fi

  sleep 5
done
