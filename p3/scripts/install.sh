#!/bin/bash
# Docker, kubectl, k3d 설치 (root로 실행: Vagrant provisioner 또는 sudo ./install.sh)
set -euo pipefail

# kubectl/docker를 쓸 일반 유저 (sudo로 실행했으면 그 유저, 아니면 vagrant)
TARGET_USER="${SUDO_USER:-vagrant}"
ARCH="$(dpkg --print-architecture)"   # amd64 / arm64

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates docker.io

# k3d는 k3s 노드를 Docker 컨테이너로 띄우므로 Docker 데몬이 필수
systemctl enable --now docker
if id "$TARGET_USER" &>/dev/null; then
  usermod -aG docker "$TARGET_USER"   # sudo 없이 docker / k3d 사용
fi

# kubectl (최신 stable)
if ! command -v kubectl &>/dev/null; then
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl"
  chmod +x /usr/local/bin/kubectl
fi

# k3d (공식 설치 스크립트 → /usr/local/bin/k3d)
if ! command -v k3d &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# 과제 예시처럼 k 로 kubectl 사용
if id "$TARGET_USER" &>/dev/null; then
  BASHRC="$(getent passwd "$TARGET_USER" | cut -d: -f6)/.bashrc"
  grep -q "alias k=kubectl" "$BASHRC" 2>/dev/null || echo "alias k=kubectl" >> "$BASHRC"
fi

docker --version
kubectl version --client
k3d version
