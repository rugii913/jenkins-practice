## 0-cron.sh: 1-cicd.sh 실행 → 30초 대기 → 반복

#!/bin/bash
while [ true ]
do
  echo "Running 1-cicd.sh"
  ./1-cicd.sh
  echo "Waiting 30 seconds"
  sleep 30
done
