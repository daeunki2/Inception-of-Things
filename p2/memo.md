1. Vagrant — 가상머신 관리
명령어	역할
vagrant up	VM 생성 및 실행, 최초 Provisioning 수행
vagrant halt	VM 종료
vagrant reload	VM 재시작 및 Vagrantfile 설정 반영
vagrant provision sunaS	setup.sh 재실행
vagrant destroy -f sunaS	VM 강제 삭제
vagrant ssh sunaS	VM에 SSH 접속
2. Kubernetes — 배포 및 상태 확인
Fedora 호스트에서 실행하는 명령어야.
명령어	역할
vagrant ssh sunaS -c "sudo k3s kubectl get nodes -o wide"	노드 상태 및 IP 확인
vagrant ssh sunaS -c "sudo k3s kubectl get pods -A"	전체 Namespace의 Pod 확인
vagrant ssh sunaS -c "sudo k3s kubectl get pods -o wide"	기본 Namespace의 Pod 상세 확인
vagrant ssh sunaS -c "sudo k3s kubectl get deployments"	App 1·2·3의 Replica 상태 확인
vagrant ssh sunaS -c "sudo k3s kubectl get deployments,services,ingress"	배포·서비스·Ingress 상태 확인
vagrant ssh sunaS -c "sudo k3s kubectl apply -f /vagrant/confs/"	YAML 설정을 Kubernetes에 적용
3. HTTP — Ingress 테스트
Fedora 호스트에서 실행해.
# App 1
curl -H "Host: app1.com" http://192.168.56.110/

# App 2
curl -H "Host: app2.com" http://192.168.56.110/

# App 3 (기본 경로)
curl http://192.168.56.110/


응답에서 메시지만 확인하고 싶다면:
curl -s -H "Host: app1.com" http://192.168.56.110/ | grep "Hello from"
curl -s -H "Host: app2.com" http://192.168.56.110/ | grep "Hello from"
curl -s http://192.168.56.110/ | grep "Hello from"


4. 시스템 상태 확인
# VM의 메모리 사용량
vagrant ssh sunaS -c "free -h"


5. Git — 작업 저장
Git 저장소 루트인 iot에서 실행해.
git status

git add p2/Vagrantfile p2/scripts/setup.sh p2/confs/

git commit -m "Complete Inception of Things Part 2"

git push -u origin daeunki2



