## 1-cicd.sh
## 변경 감지=(remote의 정보를 fetch → local와 checkout 버전과 비교)
## → 변경이 있는 경우 origin/main으로 checkout
## → checkout으로 받은 코드로 build 진행
## → 빌드 성공 시 deploy 진행

#!/bin/bash
rm -f ci-flow.log
git fetch --force origin >> ci-flow.log ## remote에서 최신 정보를 가져오고(필요할 경우 강제로 local에 반영), 이로부터 발생하는 출력(stdout)을 >>로 ci-flow.log 파일에 추가
git diff ..origin/main --exit-code > diff.txt ## ..origin/main은 현재 HEAD와 origin/main 간 차이를 의미, --exit-code는 diff 결과에 따라 종료 코드 반환, diff 결과 내용은 diff.txt에 저장 ## cf. > 기존 파일이 있다면 덮어쓰기, >>는 기존 파일이 있다면 추가
ret=$? ## $?는 직전 명령의 종료 코드를 의미, 이 값을 변수 ret에 저장

## 변경이 없는 경우 exit-code는 0
if [ $ret -eq 0 ]
then
    echo "-------------------------------------------------"
    echo "no changes"
    exit 0
fi ## if 구문을 닫음 ## cf. ;;는 case 구문에서 각 분기를 닫음

## 변경이 있다면 exit-code는 1로 계속 진행 → origin/main으로 checkout(local 코드를 최신 remote 코드로 동기화)
echo ""
echo "-------------------------------------------------"
echo "changed"
git checkout -f origin/main >> ci-flow.log

## checkout으로 받은 코드로 build 진행(2-build.sh 스크립트 실행)
echo ""
echo "-------------------------------------------------"
echo "building"
./2-build.sh
ret=$? ## 빌드 과정 성공 시 반환된 0이 저장, 실패 시 0 외의 코드 반환

if [ $ret -ne 0 ]
then
    echo ""
    echo "-------------------------------------------------"
    echo "build failed"
    exit -1 ## 실패 시 0이 아닌 종료 코드를 반환하여 상위 레벨 CI 도구가 실패로 인식할 수 있게 함
fi
echo ""
echo "-------------------------------------------------"
echo "successfully built"

## 빌드 성공 시 deploy 진행
echo ""
echo "-------------------------------------------------"
echo "deploying"
./3-1-deploy.sh
ret=$?
if [ $ret -ne 0 ]
then
    echo ""
    echo "-------------------------------------------------"
    echo "deployment failed"
    exit -1
fi
echo ""
echo "-------------------------------------------------"
echo "successfully deployed"
