#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="iot-bonus"
CONTEXT="k3d-${CLUSTER_NAME}"

# Select the kubectl binary available in the VM.
if command -v kubectl-p3 >/dev/null 2>&1; then
    KUBECTL="kubectl-p3"
else
    KUBECTL="kubectl"
fi

# Verify Docker access before managing the cluster.
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not accessible."
    exit 1
fi

# Create a dedicated Bonus cluster if it does not exist.
if ! k3d cluster list -o json | grep -q "\"name\":\"${CLUSTER_NAME}\""; then
    k3d cluster create "$CLUSTER_NAME" \
        --servers 1 \
        --agents 0 \
        --port "8080:30080@server:0" \
        --port "8081:30081@server:0" \
        --wait
else
    echo "Cluster ${CLUSTER_NAME} already exists."
    k3d cluster start "$CLUSTER_NAME"
fi

# Use the Bonus cluster explicitly to avoid modifying P3.
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context

# Create namespaces for the Bonus components.
for namespace in gitlab argocd dev; do
    "$KUBECTL" --context "$CONTEXT" create namespace "$namespace" \
        --dry-run=client -o yaml \
        | "$KUBECTL" --context "$CONTEXT" apply -f -
done

# Verify that the cluster and namespaces are available.
"$KUBECTL" --context "$CONTEXT" get nodes
"$KUBECTL" --context "$CONTEXT" get namespaces

echo "Bonus cluster setup completed."