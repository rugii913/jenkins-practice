## 3-1-deploy.sh

#!/bin/bash
## start.sh이라는 shell script를 생성 - << EOF부터 EOF까지의 내용이 들어감
## - 해당 shell script의 내용: 기존 프로세스 제거 → 새 버전 실행 → 2초 대기 후 새로 시작된 pid 출력
cat > deploy/start.sh << EOF
echo "-----------------"
echo "Terminating existing process"
echo "-----------------"
ps -eaf | grep -v grep | grep -v defunct | grep java |  awk '{print "kill -TERM "\$2}' | sh -x

echo "-----------------"
echo "Starting new version"
echo "-----------------"
nohup java -jar demo-0.0.1-SNAPSHOT.jar &
sleep 2
ps -eaf | grep -v grep | grep -v defunct | grep java |  awk '{print "new pid is "\$2}'
EOF

## 위에서 생성한 shell script의 권한을 755로 변경
chmod 755 deploy/start.sh

## scp, private key를 활용하여 서버로 패키지(바이너리 파일과 start.sh) 복사
## - /key/private.key는 Docker volume 매핑으로 가져온 것
echo "-----------------"
echo "Copying packages"
echo "-----------------"
scp -o StrictHostKeychecking=no -i /key/private.key -P 2222 deploy/* \
    user@server_1:~

## ssh를 이용하여 server_1 container의 start.sh 실행
echo "-----------------"
echo "Restarting"
echo "-----------------"
ssh -o StrictHostKeychecking=no -tt -i /key/private.key -p 2222 user@server_1 \
    "./start.sh"
