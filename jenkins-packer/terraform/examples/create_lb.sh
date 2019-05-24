#!/usr/bin/env bash

YC_FOLDER_ID=$(yc config get folder-id)


cat > create-lb.json <<EOF
{
    "folderId": "${YC_FOLDER_ID}",
    "name": "yc-auto-lb",
    "regionId": "ru-central1",
    "type": "EXTERNAL",
    "listenerSpecs": [
      {
        "port": "80",
        "protocol": "TCP",
        "externalAddressSpec": {
          "address": "",
          "ipVersion": "IPV4",
          "regionId": "ru-central1"
      }
      }
    ]
}
EOF



echo "Creating Load balancer"

curl -X POST \
  -H "Authorization: Bearer $(yc iam create-token)" \
	-H "Content-Type: application/json" \
	-k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers" \
  -d @create-lb.json
rm -rf create-lb.json

sleep 15

LB_ID=$(curl -X GET  --silent -H "Authorization: Bearer $(yc iam create-token)"  \
 -H "Content-Type: application/json" \
 -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers?folderId=${YC_FOLDER_ID}"  | jq .networkLoadBalancers[0].id | tr -d "\"")

TARGET_GROUP_ID=$(curl -X GET  --silent -H "Authorization: Bearer $(yc iam create-token)"  \
 -H "Content-Type: application/json" \
 -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups?folderId=${YC_FOLDER_ID}"  | jq .targetGroups[0].id | tr -d "\"")



 cat > attach-tg.json <<EOF
 {
     "attachedTargetGroup": {

      "targetGroupId": "${TARGET_GROUP_ID}",
      "healthChecks": [
         {
           "name": "http",
           "interval": "2s",
           "timeout": "1s",
           "unhealthyThreshold": "2",
           "healthyThreshold": "2",
           "httpOptions": {
            "port": "80",
            "path": "/index.html"
           },
         }
      ]
     }
}
EOF
echo "Attaching target group to  Load balacer"


curl -X POST \
  -H "Authorization: Bearer $(yc iam create-token)" \
	-H "Content-Type: application/json" \
	-k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers/${LB_ID}:attachTargetGroup" \
  -d @attach-tg.json


rm -rf attach-tg.json
