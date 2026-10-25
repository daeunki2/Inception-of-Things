#!/bin/bash
# k3d 클러스터 + Argo CD 구성 (root로 실행: Vagrant provisioner 또는 sudo ./setup.sh)
# $1: confs 폴더 경로 (안 주면 스크립트 기준 ../confs)
set -euo pipefail

CONFS_DIR="${1:-$(cd "$(dirname "$0")/../confs" && pwd)}"
CLUSTER="iot"
TARGET_USER="${SUDO_USER:-vagrant}"

# ① k3d 클러스터 생성 (이미 있으면 건너뜀)
#   -p 8888:8888@loadbalancer : VM의 8888 → 클러스터 LB → 앱 Service(LoadBalancer, 8888)
#   -p 8443:443@loadbalancer  : VM의 8443 → Argo CD 웹 UI
#   traefik 끔 : Argo CD 서버를 LoadBalancer로 열 때 80/443 포트가 traefik과 겹치지 않게
if ! k3d cluster list --no-headers | awk '{print $1}' | grep -qx "$CLUSTER"; then
  k3d cluster create "$CLUSTER" \
    -p "8888:8888@loadbalancer" \
    -p "8443:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --wait
fi

# root가 만든 kubeconfig를 일반 유저에게도 복사 → vagrant ssh 후 바로 kubectl 사용
if id "$TARGET_USER" &>/dev/null; then
  USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  mkdir -p "$USER_HOME/.kube"
  k3d kubeconfig get "$CLUSTER" > "$USER_HOME/.kube/config"
  chown -R "$TARGET_USER:" "$USER_HOME/.kube"
  chmod 600 "$USER_HOME/.kube/config"
fi

# ② 네임스페이스 2개 (재실행해도 에러 안 나게 apply 방식)
for ns in argocd dev; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ③ Argo CD 설치
#   CRD가 커서 client-side apply는 annotation 크기 제한에 걸림 → server-side apply
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=established crd/applications.argoproj.io --timeout=120s
echo "Argo CD 기동 대기 중..."
kubectl wait --for=condition=available deployment --all -n argocd --timeout=600s

# 웹 UI를 VM 밖(호스트 브라우저)에서 열 수 있게 LoadBalancer로 변경
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'

# ④ Application 등록 → 이후 GitHub 저장소를 보고 dev 네임스페이스에 자동 배포
kubectl apply -f "$CONFS_DIR/application.yaml"

until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do sleep 2; done
PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

IP="$(hostname -I | awk '{print $NF}')"
echo
echo "=========================================="
echo " Argo CD UI : https://${IP}:8443  (VM 안: https://localhost:8443)"
echo " 계정       : admin / ${PASSWORD}"
echo " 앱         : curl http://localhost:8888/"
echo "=========================================="
