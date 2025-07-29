#!/bin/bash

NAMESPACE="smart-home"
TIMEOUT=120
SKIP_MINIKUBE_START=0

# ANSI colors
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

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
  echo -e "${CYAN}Starting Minikube...${RESET}"
  minikube start --driver=docker --memory=3072 --cpus=2
  if [ $? -ne 0 ]; then
    echo -e "${RED}Minikube failed to start. Exiting.${RESET}"
    exit 1
  fi
else
  echo -e "${CYAN}Skipping Minikube start as requested.${RESET}"
fi

echo -e "${CYAN}Enabling ingress addon...${RESET}"
minikube addons enable ingress

echo -e "${CYAN}Opening tunnel to ingress controller...${RESET}"
nohup minikube tunnel > minikube-tunnel.log 2>&1 &

echo -e "${YELLOW}Waiting for ingress controller to be ready...${RESET}"
sleep 2
for i in {1..30}; do
  if kubectl get pods -n ingress-nginx --no-headers | grep -q "Running"; then
    echo -e "${GREEN}Ingress controller is ready.${RESET}"
    break
  fi
  sleep 2
done

if ! kubectl get pods -n ingress-nginx --no-headers | grep -q "Running"; then
  echo -e "${RED}Ingress controller did not become ready. Exiting.${RESET}"
  exit 1
fi

# ------------------ Argo CD setup ------------------
echo -e "${CYAN}Creating Argo CD namespace (if missing)...${RESET}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo -e "${CYAN}Installing Argo CD core components...${RESET}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${CYAN}Waiting for Argo CD server pod to be ready...${RESET}"
sleep 5
kubectl wait --for=condition=Ready pods --selector app.kubernetes.io/name=argocd-server -n argocd --timeout=${TIMEOUT}s

# Optional ingress for Argo UI
echo -e "${CYAN}Applying Argo CD ingress (if defined)...${RESET}"
if [ -f "../argocd/argocd-ingress.yaml" ]; then
  kubectl apply -n argocd -f ../argocd/argocd-ingress.yaml
else
  echo -e "${YELLOW}No argocd-ingress.yaml found, skipping ingress setup.${RESET}"
fi

# ------------------ Argo CD App bootstrap ------------------
echo -e "${CYAN}Bootstrapping Argo CD applications...${RESET}"

echo -e "${CYAN}Applying Argo CD App: setup_app.yaml${RESET}"
kubectl apply -n argocd -f "../argocd/setup_app.yaml"

echo -e "${YELLOW}Waiting for MQTT broker pod in '$NAMESPACE' to be ready...${RESET}"
sleep 3
podsReady=$(kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s")
if [ $? -ne 0 ]; then
  echo -e "${RED}Timeout or error waiting for pod to become ready:${RESET}"
  echo "$podsReady"
  exit 1
else
  echo -e "${GREEN}MQTT broker is ready. Proceeding...${RESET}"
fi

echo -e "${CYAN}Applying Argo CD App: backend_app.yaml${RESET}"
kubectl apply -n argocd -f "../argocd/backend_app.yaml"

echo -e "${YELLOW}Waiting for all backend pods in '$NAMESPACE' to be ready...${RESET}"
sleep 3
podsReady=$(kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s")
if [ $? -ne 0 ]; then
  echo -e "${RED}Timeout or error waiting for pods to become ready:${RESET}"
  echo "$podsReady"
  exit 1
else
  echo -e "${GREEN}Backend is ready. Proceeding...${RESET}"
fi

ARGO_APPS=(
  "frontend_app.yaml"
  "simulator_app.yaml"
  "monitoring_app.yaml"
)

for app in "${ARGO_APPS[@]}"; do
  if [ -f "../argocd/$app" ]; then
    echo -e "${CYAN}Applying Argo CD App: $app${RESET}"
    kubectl apply -n argocd -f "../argocd/$app"
  else
    echo -e "${YELLOW}Skipping missing app file: $app${RESET}"
  fi
done

echo -e "${YELLOW}Waiting for the rest of the pods in '$NAMESPACE' to be ready...${RESET}"
sleep 3
deployReady=$(kubectl wait --namespace $NAMESPACE --for=condition=available deployment --all --timeout="${TIMEOUT}s" 2>&1)
if [ $? -ne 0 ]; then
  echo -e "${RED}Timeout or error waiting for deployments to become ready:${RESET}"
  echo "$deployReady"
  exit 1
else
  podsReady=$(kubectl wait --for=condition=Ready pods --all --namespace "$NAMESPACE" --timeout="${TIMEOUT}s")
  if [ $? -ne 0 ]; then
    echo -e "${RED}Timeout or error waiting for pods to become ready:${RESET}"
    echo "$podsReady"
    exit 1
  else
    echo -e "${GREEN}All pods in '$NAMESPACE' are ready. Proceeding...${RESET}"
  fi
fi

# ------------------ DNS entries ------------------
echo -e "${CYAN}Adding DNS names to hosts file...${RESET}"

add_host_entry() {
  local host_entry="$1"
  if grep -qF "$host_entry" /etc/hosts; then
    echo -e "${YELLOW}$host_entry already exists in hosts file${RESET}"
  else
    echo "$host_entry" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}Added $host_entry to hosts file${RESET}"
  fi
}

add_host_entry "127.0.0.1 argocd.local"
add_host_entry "127.0.0.1 dashboard.local"
add_host_entry "127.0.0.1 grafana.local"

echo -e "${CYAN}Frontend: http://dashboard.local${RESET}"
echo -e "${CYAN}Grafana: http://grafana.local${RESET}"
echo -e "${CYAN}Argo CD: https://argocd.local${RESET}"

echo -e "\n${GREEN}*** Done! Argo CD is syncing your app manifests from GitHub. ***${RESET}\n"
