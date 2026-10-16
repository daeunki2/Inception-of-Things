#!/bin/bash
# ↑ shebang: 이 스크립트를 bash로 실행하라는 표시

# -e: 명령 하나라도 실패하면 즉시 종료
# -u: 선언 안 된 변수를 쓰면 에러로 종료 (오타 방지)
# -o pipefail: 파이프(|) 중간 명령이 실패해도 실패로 처리
set -euo pipefail

SERVER_IP="$1"                          # Vagrantfile의 args: [SERVER_IP, CONFS_DIR] 중 첫 번째 인자
CONFS_DIR="$2"                          # 두 번째 인자: file provisioner가 yaml을 올려둔 폴더 (/tmp/confs)
export DEBIAN_FRONTEND=noninteractive   # apt가 설치 중 질문 창을 띄우지 않게 함 (자동 설치용)

# 진행 상황 로그 ($(hostname) 은 현재 머신 이름으로 치환됨)
echo "[server] $(hostname) provisioning start (SERVER_IP=${SERVER_IP}, CONFS_DIR=${CONFS_DIR})"

apt-get update -qq              # 패키지 목록 갱신 (-qq: 출력 최소화)
apt-get install -y -qq curl     # K3s 설치 스크립트를 받기 위한 curl 설치 (-y: 자동 yes)

# SERVER_IP(192.168.56.110)가 붙어 있는 네트워크 인터페이스 이름 찾기 (예: eth1)
# ip -o -4 addr show : IPv4 주소를 인터페이스당 한 줄로 출력
# awk : 4번째 칸(IP/서브넷)이 "192.168.56.110/" 로 시작하는 줄의 2번째 칸(인터페이스 이름) 출력
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^"ip"/" {print $2}')
echo "[server] cluster interface: ${IFACE}"

# K3s server 설치
# - agent가 없으므로 K3S_TOKEN 불필요 (K3s가 알아서 생성)
# - Ingress controller(Traefik)는 K3s에 기본 포함되어 있어서 따로 설치 안 함
# curl -sfL : 설치 스크립트를 조용히(-s), 실패 시 에러(-f), 리다이렉트 따라가며(-L) 받아서
# | sh -    : 받은 스크립트를 바로 sh로 실행
# INSTALL_K3S_EXEC : 설치 스크립트에 넘기는 K3s 실행 옵션
#   server                       → controller(server) 모드로 설치
#   --node-ip ${SERVER_IP}       → 노드 IP를 NAT IP가 아닌 192.168.56.110 으로 고정
#   --flannel-iface ${IFACE}     → pod 네트워크(flannel)가 위에서 찾은 인터페이스를 사용
#   --write-kubeconfig-mode 644  → /etc/rancher/k3s/k3s.yaml 을 모두 읽기 가능하게 → vagrant 계정도 sudo 없이 kubectl
curl -sfL https://get.k3s.io/ | INSTALL_K3S_EXEC="server \
  --node-ip ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --write-kubeconfig-mode 644" sh -

# 노드가 Ready 될 때까지 대기 (최대 5분)
# K3s는 설치 직후 바로 명령을 못 받을 수 있어서, 준비 전에 apply 하면 실패함
# kubectl get nodes 출력에 " Ready" 가 보이면 루프 탈출 (2>/dev/null: 준비 전 에러 메시지 숨김)
# " Ready" 앞의 공백 덕분에 "NotReady" 는 매칭 안 됨
# grep -q 대신 >/dev/null 사용: -q는 찾자마자 종료해서 pipefail에서 kubectl이 SIGPIPE 실패로 잡힐 수 있음
for i in $(seq 1 60); do
  kubectl get nodes 2>/dev/null | grep " Ready" >/dev/null && break
  echo "[server] waiting for node Ready... (${i})"
  sleep 5
done
kubectl get nodes -o wide       # 노드 상태 출력 (INTERNAL-IP 가 192.168.56.110 인지 확인용)

# confs 폴더 안의 yaml 전부를 K3s에 제출 (app1, app2, app3, ingress)
# apply는 "없으면 만들고, 있으면 바뀐 부분만 수정" → 여러 번 실행해도 안전
echo "[server] applying manifests in ${CONFS_DIR}"
kubectl apply -f "${CONFS_DIR}"

# 앱 3개의 Deployment가 Available(원하는 수의 pod가 준비됨)이 될 때까지 대기 (최대 5분)
# 첫 실행은 이미지 다운로드 때문에 시간이 좀 걸림
echo "[server] waiting for apps to be available..."
kubectl wait --for=condition=Available deployment --all --timeout=300s

# 결과 출력: Deployment / pod / Service / Ingress 한눈에 확인
kubectl get deploy,pods,svc,ingress -o wide

echo "[server] done"            # 설치 완료 로그
