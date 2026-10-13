require "securerandom"
require "fileutils"



LOGIN     = "suna"
BOX       = "debian/trixie64"
SERVER_IP = "192.168.56.110"
WORKER_IP = "192.168.56.111"


TOKEN_FILE = File.join(File.dirname(FILE), "confs", "k3s_token") // 호스트에 저장
unless File.exist?(TOKEN_FILE)
  FileUtils.mkdir_p(File.dirname(TOKEN_FILE))
  File.write(TOKEN_FILE, SecureRandom.hex(32))
end
K3S_TOKEN = File.read(TOKEN_FILE).strip

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.boot_timeout = 900
  config.vm.synced_folder".","/vagrant",disabled:true // 공유파일 문제 있어서 종료
  config.vm.provider "libvirt" do |lv|  
    lv.default_prefix = ""
    lv.cpus = 1
    lv.memory = 1024
  end

  # Server
  config.vm.define "#{LOGIN}S" do |server|
    server.vm.hostname = "#{LOGIN}S"
    server.vm.network "private_network", ip: SERVER_IP,
      libvirtnetwork_name: "iot-p1",
      libvirtforward_mode: "none"
    server.vm.provision "shell", path: "scripts/server.sh",
      args: [SERVER_IP], env: { "K3S_TOKEN" => K3S_TOKEN } / 보안으로 
  end

  # ServerWorker
  config.vm.define "#{LOGIN}SW" do |worker|
    worker.vm.hostname = "#{LOGIN}SW"
    worker.vm.network "private_network", ip: WORKER_IP,
      libvirtnetwork_name: "iot-p1",
      libvirtforward_mode: "none"
    worker.vm.provision "shell", path: "scripts/agent.sh",
      args: [SERVER_IP, WORKER_IP], env: { "K3S_TOKEN" => K3S_TOKEN }
  end
end


차이점 = 반복되는 부분 변수화 + 공유폴더 이슈로 호스트에 저장하고 env로 받아서 사용 
-------------------------------------------------------------


set -euo pipefail

SERVER_IP="$1"
: "${K3S_TOKEN:?K3S_TOKEN is not set}"
export DEBIAN_FRONTEND=noninteractive

echo "[server] $(hostname) provisioning start (SERVER_IP=${SERVER_IP})"

apt-get update -qq
apt-get install -y -qq curl

IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^"ip"/" {print $2}')
echo "[server] cluster interface: ${IFACE}"

K3s server(controller) 설치, 미리 정한 token 사용
curl -sfL https://get.k3s.io/ | K3S_TOKEN="${K3S_TOKEN}" INSTALL_K3S_EXEC="server \
  --node-ip ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --write-kubeconfig-mode 644" sh -

echo "[server] done"



-------------------------------------------------------

#!/bin/bash
set -euo pipefail

SERVER_IP="$1"
WORKER_IP="$2"
: "${K3S_TOKEN:?K3S_TOKEN is not set}"
export DEBIAN_FRONTEND=noninteractive

echo "[agent] $(hostname) provisioning start (SERVER_IP=${SERVER_IP}, WORKER_IP=${WORKER_IP})"

apt-get update -qq
apt-get install -y -qq curl

IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP" '$4 ~ "^"ip"/" {print $2}')
echo "[agent] cluster interface: ${IFACE}"

server의 API(6443)가 응답할 때까지 대기 (최대 5분)
for i in $(seq 1 60); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://${server_ip}:6443/" || true)
  [ "$code" != "000" ] && break
  echo "[agent] waiting for server API... (${i})"
  sleep 5
done

K3s agent 설치: K3S_URL이 있으면 설치 스크립트가 agent 모드로 설치함
curl -sfL https://get.k3s.io/ | \
  K3S_URL="https://${server_ip}:6443/" \
  K3S_TOKEN="${K3S_TOKEN}" \
  INSTALL_K3S_EXEC="agent --node-ip ${WORKER_IP} --flannel-iface ${IFACE}" sh -

echo "[agent] done"



인터페이스??
- vm두개를 설치를 하면서 기본을 할당을 받음. 그거로 "외부"랑 소통.
- 하지만 항상 값이 변함. 기본값의 경우 vm설치마다 다름.
- 그래서 나눈다. 

- 빈공간 인터페이스 아이피랑 통신 네트워크? >> 약간의 빈틈... 요거는 같이 좀 채우면 좋을거 같습니다. 

- vm의 초기 ip는 랜덤에 생성해 진다...! 

- 쿠버네티스는 뭐지????
- 도커와의 차이????
- 도커는 컨테이너 이미지 만드는 역할
- 쿠버네티스는 이미지를 생성은 불가.! 
- 쿠버네티스는 클러스터화 그 클러스터안에서 도커 실행
- 서버가 점점 커지자나요?
- 로그인 서버가 1{abc} 2{abc} 3{abc} 4{abc} 5{abc} > 쿠버네티스{도커}

- 아마존 자격증 공부하면서 본 관점
- 쿠버네티스와 일반 pc와의 차이
- 일반 pc는 또 하나의 클라우드 관리 시스템을 올린다.
- 쿠버네티스 관련된 서비스가 있으면 좋다...! 그 안에서 확장성 유연성...!

쿠버네티스 
- p2 p3 죽을때 노드가 죽거나 무언가 죽을때 자동으로 살려준다...! 


쿠버네티스가 뭐고 왜 필요하고 정확하게 뭐냐. ! 
> 좀 더 해야함. 

인터페이스 요 부분도 조금 더 공부하면 좋을거 같음...! 
명령어들 에러의 종류와 원인 해결법 >>> 해봐야함...! 

----------------------------------------
파트 1 후기

가상머신을 공부한 느낌 
여러 pc를 연결해보라는 의미이지 않을까...?
인터페이스 이해는 해봐라...!

---------------------------------------
2 3 는 사실 연결성이 강함...!
2 
3는 자동화
양도 사실 작음...! 

---------
보너스도 사실 연결성이 매우 강하다고 합니다....!
--------------------------------------
깃랩이라는 서비스를 설치? 사용 가능하게 구현? 으로 알고 있음...!


---------
2는 다음주 화요일 저녁에 같이 나눔을 할거고.
학교 가서 직접 해보면 최고...!
스크립트 작성 정도는 하고 만나면 좋을거 같아요...! 