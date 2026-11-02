
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="iot-p3"
CONTEXT="k3d-${CLUSTER_NAME}"

# Create Kubernetes cluster
if ! k3d cluster list | grep -q "^${CLUSTER_NAME}[[:space:]]"; then
    k3d cluster create "$CLUSTER_NAME" --agents 0
fi

# Select the new cluster
kubectl config use-context "$CONTEXT"

# Create namespaces
kubectl create namespace argocd \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace dev \
    --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait until Argo CD is ready
kubectl rollout status deployment/argocd-server \
    -n argocd --timeout=300s

# Verify cluster
kubectl get nodes
kubectl get pods -n argocd
kubectl get namespaces
