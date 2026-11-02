
#!/usr/bin/env bash
set -euo pipefail

# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Install Docker
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
fi

sudo systemctl enable --now docker

# Install k3d
if ! command -v k3d >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
        -o /tmp/k3d-install.sh

    bash /tmp/k3d-install.sh
fi

# Verify installation
sudo docker version
k3d version
kubectl version --client
