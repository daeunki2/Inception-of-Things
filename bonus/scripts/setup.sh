
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="iot-bonus"
CONTEXT="k3d-${CLUSTER_NAME}"
ARGOCD_VERSION="v2.14.11"

# 스크립트 위치를 기준으로 설정 파일 경로를 계산합니다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$(cd "${SCRIPT_DIR}/../confs" && pwd)"

# VM에 설치된 kubectl 실행 파일을 선택합니다.
if command -v kubectl-p3 >/dev/null 2>&1; then
    KUBECTL="kubectl-p3"
elif command -v kubectl >/dev/null 2>&1; then
    KUBECTL="kubectl"
else
    echo "[ERROR] kubectl이 설치되어 있지 않습니다."
    exit 1
fi

# Bonus 클러스터에 Kubernetes 명령을 실행합니다.
kube() {
    sudo "$KUBECTL" --context "$CONTEXT" "$@"
}

# 필요한 명령어가 설치되어 있는지 확인합니다.
for command in docker k3d; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "[ERROR] ${command}이 설치되어 있지 않습니다."
        exit 1
    fi
done

# Docker 데몬에 접근할 수 있는지 확인합니다.
if ! sudo docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker daemon에 접근할 수 없습니다."
    exit 1
fi

# 필요한 설정 파일이 존재하는지 확인합니다.
for file in \
    gitlab-storage.yaml \
    gitlab-deployment.yaml \
    gitlab-service.yaml \
    argocd-service.yaml \
    application.yaml
do
    if [[ ! -f "${CONF_DIR}/${file}" ]]; then
        echo "[ERROR] 설정 파일이 없습니다: ${CONF_DIR}/${file}"
        exit 1
    fi
done

# Bonus 전용 Kubernetes 클러스터를 준비합니다.
echo "[INFO] Bonus 클러스터 준비 중..."

if ! sudo k3d cluster list -o json | grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${CLUSTER_NAME}\""; then
    echo "[INFO] 새로운 Bonus 클러스터를 생성합니다."

    sudo k3d cluster create "$CLUSTER_NAME" \
        --servers 1 \
        --agents 0 \
        --port "8080:30080@server:0" \
        --port "8081:30081@server:0" \
        --port "8888:8888@loadbalancer" \
        --wait
else
    echo "[INFO] 기존 클러스터를 시작합니다."
    sudo k3d cluster start "$CLUSTER_NAME"
fi

# 올바른 Kubernetes 클러스터에 연결되었는지 확인합니다.
echo "[INFO] Kubernetes 클러스터 확인 중..."
kube get nodes

# GitLab, Argo CD, Playground 네임스페이스를 준비합니다.
echo "[INFO] 네임스페이스 준비 중..."

for namespace in gitlab argocd dev; do
    kube create namespace "$namespace" \
        --dry-run=client -o yaml \
        | kube apply -f -
done

# GitLab 데이터를 저장할 PVC를 생성합니다.
echo "[INFO] GitLab 스토리지 준비 중..."
kube apply -n gitlab -f "${CONF_DIR}/gitlab-storage.yaml"

# GitLab Deployment와 외부 접속 Service를 적용합니다.
echo "[INFO] GitLab 배포 중..."
kube apply -n gitlab -f "${CONF_DIR}/gitlab-deployment.yaml"
kube apply -n gitlab -f "${CONF_DIR}/gitlab-service.yaml"

# GitLab Pod가 Ready 상태가 될 때까지 기다립니다.
echo "[INFO] GitLab 준비 대기 중..."
kube rollout status deployment/gitlab \
    -n gitlab \
    --timeout=900s

echo "[INFO] GitLab 배포 완료"

# 공식 Argo CD 설치 매니페스트를 적용합니다.
echo "[INFO] Argo CD 설치 중..."

kube apply -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Argo CD 서버가 정상 실행될 때까지 기다립니다.
echo "[INFO] Argo CD 서버 준비 대기 중..."
kube rollout status deployment/argocd-server \
    -n argocd \
    --timeout=300s

# Git 저장소를 읽는 Repository Server를 확인합니다.
echo "[INFO] Argo CD Repository Server 준비 대기 중..."
kube rollout status deployment/argocd-repo-server \
    -n argocd \
    --timeout=300s

# Git과 Kubernetes 상태를 비교하는 컨트롤러를 확인합니다.
echo "[INFO] Argo CD Application Controller 준비 대기 중..."
kube rollout status statefulset/argocd-application-controller \
    -n argocd \
    --timeout=300s

# 브라우저에서 Argo CD에 접속할 수 있도록 Service를 설정합니다.
echo "[INFO] Argo CD 외부 접속 Service 설정 중..."
kube apply -n argocd -f "${CONF_DIR}/argocd-service.yaml"

# GitLab 저장소가 실제로 접근 가능한지 확인합니다.
echo "[INFO] GitLab 저장소 확인 중..."

GITLAB_REPO_URL="http://gitlab.gitlab.svc.cluster.local/chanypar/iot.git"

# 이전 실행에서 남아 있을 수 있는 확인용 Pod를 정리합니다.
kube delete pod gitlab-repo-check \
    -n gitlab \
    --ignore-not-found \
    --wait=true

# 임시 Pod를 생성하여 GitLab 저장소에 접근합니다.
# git ls-remote는 저장소의 원격 Git 참조를 조회합니다.
if ! kube run gitlab-repo-check \
    -n gitlab \
    --image=alpine/git:latest \
    --restart=Never \
    --rm \
    -i \
    --command -- \
    git ls-remote "$GITLAB_REPO_URL" HEAD; then

    echo "[ERROR] GitLab 저장소에 접근할 수 없습니다."
    echo "[ERROR] GitLab 프로젝트 생성 및 공개 설정을 확인하세요."
    exit 1
fi

echo "[INFO] GitLab 저장소 확인 완료"

# 저장소 확인이 성공한 경우에만 Argo CD Application을 등록합니다.
echo "[INFO] Argo CD Application 등록 중..."
kube apply -n argocd -f "${CONF_DIR}/application.yaml"

# 설치된 Kubernetes 리소스의 최종 상태를 확인합니다.
echo ""
echo "========== Final Status =========="

echo ""
echo "=== GitLab Pods ==="
kube get pods -n gitlab

echo ""
echo "=== Argo CD Pods ==="
kube get pods -n argocd

echo ""
echo "=== Playground Pods ==="
kube get pods -n dev

echo ""
echo "=== Argo CD Applications ==="
kube get applications -n argocd

echo ""
echo "=== Namespaces ==="
kube get namespaces

echo ""
echo "=================================="

echo "[SUCCESS] Bonus 클러스터 설정 완료"
echo "[INFO] GitLab: http://192.168.56.110:8080"
echo "[INFO] Argo CD: https://192.168.56.110:8081"
