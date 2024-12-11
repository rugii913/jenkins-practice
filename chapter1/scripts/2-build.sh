## 2-build.sh: 빌드 작업을 위한 스크립트
## 데이터 정리할 디렉토리 생성 → 디렉토리 이동 및 빌드 → ./deploy 디렉토리로 복사

#!/bin/bash
mkdir deploy
(cd ~/jenkins-practice/projects/spring-app; gradle build) ## cf. ()는 subshell에서 명령을 실행하기 위한 구문 → cd 명령어와 같은 환경 변화가 원래의 shell에 영향을 주지 않음 ## cf. ;는 한 줄 안에서 여러 명령어를 연결하는 command separator
cp ~/jenkins-practice/projects/spring-app/build/libs/demo-0.0.1-SNAPSHOT.jar ./deploy/
