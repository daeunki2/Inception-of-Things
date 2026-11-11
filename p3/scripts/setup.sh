
#!/usr/bin/env bash
set -euo pipefail

# 관리자 권한 확인
if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo bash scripts/setup.sh" >&2
    exit 1
fi

CLUSTER_NAME="iot-p3"
CONTEXT="k3d-${CLUSTER_NAME}"
ARGOCD_VERSION="v2.14.11"
KUBECTL="/usr/local/bin/kubectl-p3"
APPLICATION_FILE="/home/vagrant/p3/confs/application.yaml"

export KUBECONFIG="/root/.kube/config"

# 필수 도구 및 설정 파일 확인
for command in docker k3d "$KUBECTL"; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing required command: $command" >&2
        exit 1
    fi
done

if [[ ! -f "$APPLICATION_FILE" ]]; then
    echo "Application file not found: $APPLICATION_FILE" >&2
    exit 1
fi

# P2 K3s 서비스 중지 (설치 및 데이터는 유지)
if systemctl is-active --quiet k3s; then
    systemctl stop k3s
fi

# Docker 서비스 시작
systemctl enable --now docker

# P3 클러스터 생성 또는 기존 클러스터 시작
if k3d cluster list | awk 'NR > 1 {print $1}' | grep -Fxq "$CLUSTER_NAME"; then
    echo "Starting existing k3d cluster: $CLUSTER_NAME"
    k3d cluster start "$CLUSTER_NAME"
else
    echo "Creating k3d cluster: $CLUSTER_NAME"
    k3d cluster create "$CLUSTER_NAME" \
        --servers 1 \
        --agents 0 \
        --port "8888:8888@loadbalancer"
fi

# P3 클러스터 kubeconfig 설정
mkdir -p /root/.kube

k3d kubeconfig merge "$CLUSTER_NAME" \
    --kubeconfig-merge-default >/dev/null

"$KUBECTL" config use-context "$CONTEXT"

# Kubernetes Node 준비 확인
"$KUBECTL" wait \
    --for=condition=Ready \
    nodes --all \
    --timeout=180s

# Namespace 생성 또는 유지
"$KUBECTL" create namespace argocd \
    --dry-run=client -o yaml | "$KUBECTL" apply -f -

"$KUBECTL" create namespace dev \
    --dry-run=client -o yaml | "$KUBECTL" apply -f -

# 고정된 버전의 Argo CD 설치
"$KUBECTL" apply \
    --server-side \
    --force-conflicts \
    -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Argo CD 주요 구성 요소 준비 확인
"$KUBECTL" rollout status deployment/argocd-server \
    -n argocd --timeout=300s

"$KUBECTL" rollout status deployment/argocd-repo-server \
    -n argocd --timeout=300s

"$KUBECTL" rollout status statefulset/argocd-application-controller \
    -n argocd --timeout=300s

# Argo CD Application CRD 준비 확인
"$KUBECTL" wait \
    --for=condition=Established \
    crd/applications.argoproj.io \
    --timeout=120s

# Playground Application 등록
"$KUBECTL" apply -f "$APPLICATION_FILE"

# 최종 상태 확인
echo "=== Kubernetes Nodes ==="
"$KUBECTL" get nodes

echo "=== Namespaces ==="
"$KUBECTL" get namespaces

echo "=== Argo CD Pods ==="
"$KUBECTL" get pods -n argocd

echo "=== Argo CD Applications ==="
"$KUBECTL" get applications -n argocd

echo "=== Playground Deployments ==="
"$KUBECTL" get deployments -n dev

echo "P3 setup completed."
