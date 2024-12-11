## 3-2-deploy-with-rolling-update.sh

#!/bin/bash
cat > deploy/start.sh << EOF
echo "-----------------"
echo "Removing from LB"
echo "-----------------"
touch about-to-shutdown
sleep 5

echo "-----------------"
echo "Terminating existing process"
echo "-----------------"
ps -eaf | grep -v grep | grep -v defunct | grep java |  awk '{print "kill -TERM "\$2}' | sh -x

echo "-----------------"
echo "Starting new version"
echo "-----------------"
nohup java -jar demo-0.0.1-SNAPSHOT.jar --application.branch=\`hostname\` &
sleep 10
ps -eaf | grep -v grep | grep -v defunct | grep java |  awk '{print "new pid is "\$2}'

echo "-----------------"
echo "Adding back to LB"
echo "-----------------"
rm about-to-shutdown
sleep 5

EOF

chmod 755 deploy/start.sh

for server in server_1 server_2
do
  echo "-----------------"
  echo "Starting deployment on $server"
  echo "-----------------"
  scp -o StrictHostKeychecking=no -i /key/private.key -P 2222 deploy/* \
      user@$server:~

  echo "-----------------"
  echo "Restarting on $server"
  echo "-----------------"
  ssh -o StrictHostKeychecking=no -tt -i /key/private.key -p 2222 \
      user@$server "./start.sh"
  echo "-----------------"
  echo "Deployment on $server completed"
  echo "-----------------"
done
