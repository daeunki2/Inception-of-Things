1. 학교 PC → VM
   - VM IP: 192.168.56.110
   - GitLab: 8080
   - Argo CD: 8081
   - VirtualBox의 Private Network 사용

2. VM → Docker 컨테이너 (k3d Node)
   - Docker Port Mapping
   - VM:8080 → Node:30080
   - VM:8081 → Node:30081

3. k3d Node → Kubernetes Service
   - NodePort를 통해 요청 전달
   - GitLab Service: 30080
   - Argo CD Service: 30081

4. Kubernetes Service → Pod
   - Service가 label selector로 대상 Pod를 선택
   - Kubernetes 네트워크가 실제 Pod IP로 요청 전달

5. Pod → 애플리케이션 컨테이너
   - GitLab 또는 Argo CD가 HTTP 요청 처리


---------------------------
1. Argo CD → Kubernetes DNS
   - GitLab Service의 DNS 이름 조회

2. Kubernetes DNS → GitLab Service 주소 확인
   - CoreDNS가 Service의 ClusterIP 반환

3. Argo CD → GitLab Service
   - Kubernetes 내부 네트워크로 HTTP 요청

4. GitLab Service → GitLab Pod
   - Service가 GitLab Pod로 요청 전달

5. GitLab → Argo CD
   - Git 저장소의 파일과 변경사항 제공

6. Argo CD → Kubernetes API Server
   - GitLab에서 읽은 YAML을 기준으로 배포 상태 동기화

7. Kubernetes → Playground Pod
   - Deployment를 통해 Pod 생성 및 업데이트


--------------------------------
gitlab-storage.yaml — GitLab 데이터를 어디에 저장할 것인가?



gitlab-deployment.yaml — GitLab 컨테이너를 어떻게 실행할 것인가?



gitlab-service.yaml — 실행된 GitLab에 어떻게 접근할 것인가?