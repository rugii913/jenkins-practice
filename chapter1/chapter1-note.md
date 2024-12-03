## 실습 환경 준비

### 구성 설명
- Docker container 4개
  - LB: 소프트웨어 로드 밸런서인 haproxy 구동
  - server_1, server_2: Spring Boot 구동
  - cicd: 빌드 수행, 변경 감지, 배포 진행
- 이들은 Docker network를 통해 연결됨
  - LB는 server_1과 server_2로 로드밸런싱
  - cicd는 server_1, server_2를 배포

### 실습을 위한 패스 생성 및 이동
- `mkdir ~/jenkins-practice` `cd ~/jenkins-practice`

### SSH 키 생성
- `docker run --rm -it --entrypoint /keygen.sh linuxserver/openssh-server`
  - 생성된 private key를 ~/practice/key/private.key에 저장
  - 생성된 public key를 ~/practice/key/public.key에 저장
  - cf. echo "..." > \[파일 이름\]
- private.key 파일 권한 설정
  - `chmod 400 ~/jenkins-practice/key/private.key`
  - cf. Windows의 경우 GUI로 설정
    - 파일 우클릭 → 속성 → 보안 탭 → 고급 → 상속 사용 안 함  
→ "상속된 사용 권한을 이 개체에 대한 명시적 사용 권한으로 변환합니다." 클릭  
→ 소유자 외 다른 보안 주체 모두 제거 → 소유자 계정 권한 편집(읽기 권한만 부여)
    - 하지만 원활한 진행을 위해선 Ubuntu에서 실습을 진행하는 편이 나음
  - cf. chmod \[owner\]\[group\]\[other\]
    - 각 값에서 r = 4, w = 2, x = 1
    - 자세한 내용은 Unix-like의 permission 관련 검색
    - 참고
      - [Computer Hope - Linux chmod command](https://www.computerhope.com/unix/uchmod.htm)
      - [기타 블로그 - 리눅스 파일 & 디렉토리 권한 (소유권 / 허가권 / 특수권한)](https://inpa.tistory.com/entry/LINUX-%F0%9F%93%9A-%ED%8C%8C%EC%9D%BC-%EA%B6%8C%ED%95%9C-%EC%86%8C%EC%9C%A0%EA%B6%8C%ED%97%88%EA%B0%80%EA%B6%8C-%F0%9F%92%AF-%EC%A0%95%EB%A6%AC#%EC%86%8C%EC%9C%A0%EA%B6%8C__%ED%97%88%EA%B0%80%EA%B6%8C_%ED%99%95%EC%9D%B8_%EB%B0%A9%EB%B2%95)
  - cf. 권한 확인 방법: la 혹은 ls -al 사용

### server_1 / server_2 실행
- docker network 생성: `docker network create jenkins-practice`
- cf. SSH 연결을 위해 oepnssh-server 기반으로 생성
- server_1 실행
  ```text
  docker run -d --rm --name=server_1 --hostname=server_1 \
  -v ~/jenkins-practice/key:/key \
  -e PUBLIC_KEY_FILE=/key/public.key -e SUDO_ACCESS=true -e USER_NAME=user  \
  --network=jenkins-practice \
  lscr.io/linuxserver/openssh-server:latest
  ```
- server_2 실행
  ```text
  docker run -d --rm --name=server_2 --hostname=server_2 \
  -v ~/jenkins-practice/key:/key \
  -e PUBLIC_KEY_FILE=/key/public.key -e SUDO_ACCESS=true -e USER_NAME=user  \
  --network=jenkins-practice \
  lscr.io/linuxserver/openssh-server:latest
  ```
- server_1, server_2 에 openjdk, python3 설치
  - `docker exec server_1 apk add --update openjdk17 python3`
  - `docker exec server_2 apk add --update openjdk17 python3`

### haproxy
- haproxy 설치
  - haproxy 설정 파일 만들기
    ```text
    mkdir ~/jenkins-practice/haproxy
    cat > ~/jenkins-practice/haproxy/haproxy.cfg << EOF
    defaults
      mode http
      timeout client 10s
      timeout connect 5s
      timeout server 10s
      timeout http-request 10s

    frontend frontend
      bind 0.0.0.0:8080
      default_backend servers

    backend servers
      option httpchk
      http-check send meth GET  uri /health
      server server1 server_1:8080 check
      server server2 server_2:8080 check
    EOF
    ```
  - ~/jenkins-practice/haproxy/haproxy.cfg 파일이 만들어지고, defaults부터 EOF 전까지의 내용이 담김
- haproxy docker 실행
  ```text
  docker run -d --name haproxy --restart always \
  --network jenkins-practice \
  -p 8081:8080 \
  -v ~/jenkins-practice/haproxy:/usr/local/etc/haproxy \
  haproxy
  ```
- 로드 밸런서 haproxy와 서버 구동 확인하기
  - `docker exec -it server_1 bash` → server_1 container 안으로 붙기
  - `touch health` → health라는 파일 만들어주기
  - `python3 -m http.server 8080` → python 기반 간단한 서버 구동
  - 이후 브라우저에서 localhost:8081로 접속하면 확실히 서버가 구동 중임을 확인 가능
  - cf. container에서 빠져나오기: exit

### cicd 설치
- cicd 설치
  ```text
  docker run -d --rm --name=cicd \
  -v ~/practice/key/:/key \
  --hostname=cicd \
  --network=jenkins-practice \
  gradle:7.6.1-jdk17 sleep 9999999999
  ```
  - cf. 원래 시작한 뒤 대기 없이 죽는 프로세스이므로 sleep ...으로 강제로 sleep 하게 만듦
- vim 설치
  - `docker exec cicd apt-get update`
  - `docker exec cicd apt-get install -y vim`
