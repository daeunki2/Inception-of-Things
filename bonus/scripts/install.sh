#!/usr/bin/env bash
set -euo pipefail

# Bonus는 Part 3에서 준비한 Ubuntu VM을 재사용합니다.
# 따라서 Docker, k3d, kubectl을 중복 설치하지 않고 기존 환경을 확인합니다.

# Ubuntu 환경인지 확인합니다.
if [[ ! -f /etc/os-release ]] || ! grep -qi ubuntu /etc/os-release; then
    echo "[ERROR] Ubuntu 환경에서 실행해야 합니다."
    exit 1
fi

echo "[INFO] Ubuntu 환경 확인 완료"

# Docker가 설치되어 있는지 확인합니다.
if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker가 설치되어 있지 않습니다."
    echo "Part 3의 설치 스크립트를 먼저 실행하세요."
    exit 1
fi

# Docker 데몬이 실행 중이고 접근 가능한지 확인합니다.
# 일반 사용자 권한으로 접근할 수 없으면 sudo로 다시 확인합니다.
if docker info >/dev/null 2>&1; then
    echo "[INFO] Docker 접근 확인 완료"
elif sudo -n docker info >/dev/null 2>&1; then
    echo "[INFO] sudo 권한으로 Docker 접근 확인 완료"
else
    echo "[ERROR] Docker 데몬에 접근할 수 없습니다."
    echo "Docker 실행 상태와 사용자 권한을 확인하세요."
    exit 1
fi

# k3d가 설치되어 있는지 확인합니다.
# k3d는 Docker 컨테이너를 이용해 Kubernetes 클러스터를 생성합니다.
if ! command -v k3d >/dev/null 2>&1; then
    echo "[ERROR] k3d가 설치되어 있지 않습니다."
    echo "Part 3의 설치 스크립트를 먼저 실행하세요."
    exit 1
fi

echo "[INFO] k3d 설치 확인 완료"

# Kubernetes를 제어하는 kubectl을 확인합니다.
# Part 3에서 설치한 kubectl-p3를 우선 사용합니다.
if command -v kubectl-p3 >/dev/null 2>&1; then
    KUBECTL="kubectl-p3"
elif command -v kubectl >/dev/null 2>&1; then
    KUBECTL="kubectl"
else
    echo "[ERROR] kubectl이 설치되어 있지 않습니다."
    exit 1
fi

echo "[INFO] kubectl 설치 확인 완료"

# 설치된 도구의 버전을 출력합니다.
echo ""
echo "========== Installed Versions =========="

docker --version
k3d version
"$KUBECTL" version --client

echo "========================================"

# 모든 필수 도구가 준비됐음을 알립니다.
echo ""
echo "[SUCCESS] Bonus 실행에 필요한 도구가 준비됐습니다."
echo "[INFO] 다음 단계: ./scripts/setup.sh"