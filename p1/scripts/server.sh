#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110" #사설 네트워크용
TOKEN_FILE="/vagrant/.k3s-token" #토큰 저장 장소

IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" {print $2; exit}')
#사설 네트워크 아이피의 인터페이스 추출
if [ -z "$IFACE" ]; then
    echo "Network interface not found"
    exit 1
fi

# 기본적으로 주어지는 인터페이스가 있고. 

echo "Installing K3s Server..."

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh
#기본 네트워크 사용하여 k3s설치 스크립트 다운
# 기본 네트워크 기본 인터페이스 

INSTALL_K3S_EXEC="server \
    --node-ip ${SERVER_IP} \
    --advertise-address ${SERVER_IP} \ㅇ
    --flannel-iface ${IFACE}" \주
    sh /tmp/install-k3s.sh
#서버모드, 아이피 사설네트워크로 지정, 노드가 사용할 아이피, 인터페이스 지정
echo "Waiting for K3s token..."

until [ -s /var/lib/rancher/k3s/server/node-token ]; do
    sleep 2
done
#토큰 잘 생성되도록 대기
echo "Exporting K3s token..."

cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
#토큰 복사
echo "K3s Server installation completed."


## 인터페이스랑 네트워크 아이피 포트 정확하게 구분해서 설명할 수 있으면 좋을거 같아요...!
# 예를 들어 네 가상머신에서:
# - enp0s8 (인터페이스): 네트워크 데이터를 주고받는 연결 통로
# - 192.168.56.110 (IP): 그 인터페이스에 할당된 주소
# - 6443, 8080 (포트): 해당 IP로 들어온 통신을 어느 서비스에 전달할지 구분하는 번호