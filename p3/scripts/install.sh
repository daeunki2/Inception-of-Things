#!/usr/bin/env bash
set -euo pipefail

# Ubuntu VM에서 실행하며, 관리자 권한이 필요한 명령은 sudo로 실행합니다.
# 현재 P2의 kubectl 심볼릭 링크를 보존하기 위해 P3 전용 실행 파일을 설치합니다.
KUBECTL_VERSION="v1.35.5"
K3D_VERSION="v5.9.0"
KUBECTL_BIN="/usr/local/bin/kubectl-p3"
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"

# 패키지 저장소 접근과 HTTPS 다운로드에 필요한 기본 도구를 설치합니다.
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Docker가 없으면 공식 APT 저장소를 등록하고 Docker Engine을 설치합니다.
if ! command -v docker >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF_DOCKER
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF_DOCKER

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Docker 데몬을 즉시 시작하고 VM 재부팅 후에도 자동 시작되도록 설정합니다.
sudo systemctl enable --now docker

# k3d가 없으면 지정한 버전의 공식 설치 스크립트를 다운로드하여 실행합니다.
if ! command -v k3d >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
        -o /tmp/k3d-install.sh
    TAG="$K3D_VERSION" bash /tmp/k3d-install.sh
fi

# P2에서 쓰는 /usr/local/bin/kubectl 링크는 건드리지 않습니다.
# Kubernetes 공식 바이너리와 SHA-256 체크섬을 내려받아 검증한 뒤 P3 전용 이름으로 설치합니다.
if ! command -v kubectl-p3 >/dev/null 2>&1; then
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    BASE_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}"
    curl -fsSL "${BASE_URL}/kubectl" -o "${TMP_DIR}/kubectl"
    curl -fsSL "${BASE_URL}/kubectl.sha256" -o "${TMP_DIR}/kubectl.sha256"
    printf '%s  %s\n' "$(cat "${TMP_DIR}/kubectl.sha256")" "${TMP_DIR}/kubectl" | sha256sum --check
    sudo install -m 0755 "${TMP_DIR}/kubectl" "$KUBECTL_BIN"
fi

# 설치 결과를 확인합니다. Docker는 현재 사용자 권한 대신 sudo로 점검합니다.
sudo docker version
k3d version
"$KUBECTL_BIN" version --client