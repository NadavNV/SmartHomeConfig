#!/bin/bash

NAMESPACE="smart-home"
TIMEOUT=120
SKIP_MINIKUBE_START=0

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--skip)
      SKIP_MINIKUBE_START=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$SKIP_MINIKUBE_START" -eq 0 ]; then
  echo "Starting Minikube..."
  minikube start --driver=docker --memory=3072 --cpus=2

  echo "Enabling ingress addon..."
  minikube addons enable ingress

  echo "Opening tunnel to ingress controller..."
  nohup minikube tunnel > minikube-tunnel.log 2>&1 &
else
  echo "Skipping Minikube start as requested."
fi

echo "Applying LoadBalancer and Ingress..."
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-dashboard-svc.yaml

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

echo "Applying backend Kubernetes manifests in order..."

kubectl apply -f 02-mongo-secrets.yaml
kubectl apply -f 03-backend-cm.yaml
kubectl apply -f 04-backend-manifest.yaml

sleep 3

echo "Waiting for all pods in namespace '$NAMESPACE' to be ready..."
podsReady=$(kubectl wait --namespace $NAMESPACE --for=condition=ready pod --all --timeout=120s 2>&1)

if [ $? -ne 0 ]; then
  echo "Timeout or error waiting for pods to become ready:"
  echo "$podsReady"
  exit 1
else
  echo "All backend pods are ready. proceeding.."
fi

kubectl apply -f .

echo "Waiting for the rest of the pods in namespace '$NAMESPACE' to be ready..."
podsReady=$(kubectl wait --namespace smart-home --for=condition=ready pod --all --timeout=120s 2>&1)

if [ $? -ne 0 ]; then
  echo "Timeout or error waiting for pods to become ready:"
  echo "$podsReady"
  exit 1
else
  echo "All pods in 'smart-home' are ready."
fi


EXTERNAL_IP=$(kubectl get svc smart-home-dashboard-svc -n smart-home -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$EXTERNAL_IP" ]; then
  echo "LoadBalancer external IP not assigned yet"
else
  echo "External IP: $EXTERNAL_IP"
fi

echo -e "\n*** Done! ***\n"
