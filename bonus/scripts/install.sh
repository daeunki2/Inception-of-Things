#!/usr/bin/env bash
set -euo pipefail

# Check that this script is running inside the Ubuntu VM.
if [[ ! -f /etc/os-release ]] || ! grep -qi ubuntu /etc/os-release; then
    echo "Error: This script requires Ubuntu."
    exit 1
fi

# Verify that Docker is installed and the daemon is running.
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed. Run the P3 installation first."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not accessible."
    exit 1
fi

# Verify that k3d is available.
if ! command -v k3d >/dev/null 2>&1; then
    echo "Error: k3d is not installed. Run the P3 installation first."
    exit 1
fi

# Reuse the kubectl binary installed during P3.
if command -v kubectl-p3 >/dev/null 2>&1; then
    KUBECTL="kubectl-p3"
elif command -v kubectl >/dev/null 2>&1; then
    KUBECTL="kubectl"
else
    echo "Error: kubectl is not installed."
    exit 1
fi

# Display installed tool versions.
echo "Docker: $(docker --version)"
echo "k3d: $(k3d version | head -n 1)"
echo "kubectl: $($KUBECTL version --client 2>/dev/null | head -n 1)"

echo "Bonus dependencies are ready."