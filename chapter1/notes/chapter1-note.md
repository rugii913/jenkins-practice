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

### server_1 / server_2 컨테이너 실행
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

### haproxy 컨테이너 실행
- haproxy 설정
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

### cicd 컨테이너 실행
- cicd 컨테이너 실행
  ```text
  docker run -d --rm --name=cicd \
  -v ~/jenkins-practice/key/:/key \
  --hostname=cicd \
  --network=jenkins-practice \
  gradle:8.11.1-jdk17 sleep 9999999999
  ```
  - cf. 원래 시작한 뒤 대기 없이 죽는 프로세스이므로 sleep ...으로 강제로 sleep 하게 만듦
- vim 설치
  - `docker exec cicd apt-get update`
  - `docker exec cicd apt-get install -y vim`

## 도구 없이 간단히 CI CD 만들어보기
- 1\. GitHub repository에서 변경이 있는지 확인
- 2\. 변경사항이 있다면 해당 변경을 코드에 반영하고 애플리케이션을 빌드
- 3\. 빌드된 애플리케이션을 server_1 container에 복제 및 재실행

### 사전 작업
- 앞에서 진행한 작업 중 server_1, haproxy, cicd 컨테이너를 사용
  - 즉 다음과 같이 컨테이너들이 실행된 상태에서 진행
    ```text
    // 편의상 --rm 옵션은 사용하지 않았음
    docker run -d --name=server_1 --hostname=server_1 \
    -v ~/jenkins-practice/key:/key \
    -e PUBLIC_KEY_FILE=/key/public.key -e SUDO_ACCESS=true -e USER_NAME=user  \
    --network=jenkins-practice \
    lscr.io/linuxserver/openssh-server:latest

    docker run -d --name haproxy --restart always \
    --network jenkins-practice \
    -p 8081:8080 \
    -v ~/jenkins-practice/haproxy:/usr/local/etc/haproxy \
    haproxy

    docker run -d --name=cicd \
    -v ~/jenkins-practice/key/:/key \
    --hostname=cicd \
    --network=jenkins-practice \
    gradle:8.11.1-jdk17 sleep 9999999999
    ```
  - SSH 키 생성, haproxy 설정 파일 생성, cicd 컨테이너에 vim 설치 작업 등은 잘 진행됐다고 가정
  - GitHub repository https://github.com/junoyoon/fastcampus-jenkins fork하여 본인 repository로 가져온 후 진행
    - 내 경우에는 해당 repository를 fork 하지는 않고 참고하면서 점진적으로 작성
- 준비한 GitHub repository를 clone
  - cicd container 접근 및 repository clone
    ```text
    // container에 붙은 후 "~" 경로(root 디렉토리)에서 작업
    docker exec -it cicd bash
    cd ~
    git clone https://github.com/[계정]/[repository 이름.git]
    cd [repository 이름]
    ls -al
    // remote를 가리키게 하여, local을 detached HEAD 상태로 만듦
    git checkout origin/main 
    ```

### 실습 스크립트 코드 확인, 실행
- chapter 1 실습 스크립트 코드 확인
  - 실습 스크립트 복사 `cp ~/[repository 이름]/chapter1/scripts/* ./` 후 다음 파일들의 코드 확인
    - 0-cron.sh, 1-cicd.sh, 2-build.sh, 3-1-deploy.sh, 3-2-deploy-with-rolling-update.sh
- cicd 프로세스 실행
  - `./1-cicd.sh`: origin/main에서 변경된 코드가 없는 경우, 빌드 진행 전에 종료됨을 확인 가능
  - `./0-cron.sh`: 30초 주기로 1-cicd.sh 실행
- cf. 스크립트 실행 중 문제 발생 및 해결 사항
  - cicd container에서 chmod 755 ~/[repository 이름]/chapter1/scripts/*로 실행 권한을 허용해야할 수 있음
  - 3-1-deploy.sh 실행 중 server_1 container에서 /root 디렉토리 권한 문제 때문에 복사가 안 될 수 있음, 내 경우에는 chmod 777로 권한 변경
  - 3-1-deploy.sh의 `ssh -o StrictHostKeychecking=no ...` 실행 이후에도
    - ps -al로는 server_1에 실행 중인 java process를 확인할 수 없음
    - ps -ef와 같이 -a가 아니라 -e를 사용해야 java process를 확인할 수 있음
      - root가 아닌 다른 사용자 계정으로 컨테이너에 접근했기 때문으로 보임
      - Java 프로세스만 확인하려면 ps -ef | grep java 사용
    - TODO -e 옵션과 -a 옵션의 차이에 대해서 생각해볼 것
      - ps --help all 명령어로 옵션 확인해보기
      - [[Linux] ps 로 실행 중인 프로세스 확인하기](https://gracefulprograming.tistory.com/126)
      - [[LINUX] 프로세스 관리 명령어 정리 (ps / top / fg / bg / kill / nice ...)](https://inpa.tistory.com/entry/LINUX-%F0%9F%93%9A-%ED%94%84%EB%A1%9C%EC%84%B8%EC%8A%A4-%EA%B4%80%EB%A6%AC-%EB%AA%85%EB%A0%B9%EC%96%B4-%F0%9F%92%AF-%EC%A0%95%EB%A6%AC-Foreground-Background)
  - process는 정상적으로 동작하고 있는 듯한데, localhost:8081 접근 시 503 unavailable 보이는 문제 있음
