# Inception of Things — Part 1 명령어 정리

## 1. Vagrant — 가상머신 관리

| 명령어 | 설명 |
|---|---|
| `vagrant up` | Vagrantfile에 정의된 VM 두 대를 시작한다. 기본적으로 순차 처리하며, 이미 실행 중인 VM은 재생성하지 않는다. |
| `vagrant status` | VM들의 현재 상태를 확인한다. |
| `vagrant ssh daeunki2S` | Server VM에 SSH로 접속한다. |
| `vagrant ssh daeunki2SW` | Worker VM에 SSH로 접속한다. |
| `vagrant halt` | 두 VM을 종료한다. |
| `vagrant reload` | VM을 재시작하고 Vagrant 설정을 다시 적용한다. |
| `vagrant provision` | 프로비저닝 스크립트를 다시 실행한다. |
| `vagrant destroy -f` | 두 VM을 삭제한다. 주의: VM 내부 데이터도 삭제된다. |

## 2. Linux — 네트워크 확인

| 명령어 | 설명 |
|---|---|
| `ip -br addr` | 네트워크 인터페이스와 할당된 IP를 간략하게 확인한다. |
| `ip route` | 라우팅 테이블과 기본 게이트웨이를 확인한다. |
| `ping -c 4 192.168.56.110` | Server와의 네트워크 연결을 테스트한다. |
| `hostname` | 현재 VM의 호스트 이름을 확인한다. |

## 3. K3s — 클러스터 확인

| 명령어 | 설명 |
|---|---|
| `sudo systemctl status k3s` | Server에서 K3s 서비스 상태를 확인한다. |
| `sudo systemctl status k3s-agent` | Worker에서 K3s Agent 상태를 확인한다. |
| `sudo k3s kubectl get nodes` | 클러스터에 등록된 노드 목록을 확인한다. |
| `sudo k3s kubectl get nodes -o wide` | 노드 상태, IP, OS, Kubernetes 버전 등을 자세히 확인한다. |
| `sudo k3s kubectl get pods -A` | 모든 네임스페이스의 Pod 상태를 확인한다. |

## 4. Fedora 호스트에서 직접 확인

VM 내부에 접속하지 않고 명령어를 실행할 수도 있다.

```bash
vagrant ssh daeunki2S -c "sudo k3s kubectl get nodes -o wide"
```

- `vagrant ssh`: VM에 SSH 연결
- `daeunki2S`: 대상 VM 이름
- `-c`: VM 내부에서 명령어를 실행한 후 종료

## 5. 평가에서 알아야 할 핵심 개념

**Vagrant:** 가상머신 생성과 설정을 자동화하는 도구.

**VirtualBox:** 실제 가상머신을 실행하는 하이퍼바이저.

**K3s:** 경량 Kubernetes 배포판. 컨테이너 기반 애플리케이션을 관리한다.

**Server:** Kubernetes Control Plane을 실행하며 클러스터 상태를 관리한다.

**Worker:** Server에 등록되어 Pod를 실행하는 노드.

**Interface:** 네트워크 통신을 위한 연결 지점. 예: `enp0s8`.

**IP:** 네트워크에서 인터페이스에 할당되는 주소. 예: `192.168.56.110`.

**Port:** 한 IP에서 통신 대상 서비스를 구분하는 번호. 예: Kubernetes API Server의 `6443`.

**Token:** Worker가 Server에 등록할 때 사용하는 인증 정보.