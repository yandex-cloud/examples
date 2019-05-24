#!/usr/bin/env bash

YC_FOLDER_ID=$(terraform output folder_id | tr  -d "\"")

LB_ID=$(curl -X GET  --silent -H "Authorization: Bearer $(yc iam create-token)"  \
 -H "Content-Type: application/json" \
 -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers?folderId=${YC_FOLDER_ID}"  | jq .networkLoadBalancers[0].id | tr -d "\"")

TARGET_GROUP_ID=$(curl -X GET  --silent -H "Authorization: Bearer $(yc iam create-token)"  \
 -H "Content-Type: application/json" \
 -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups?folderId=${YC_FOLDER_ID}"  | jq .targetGroups[0].id | tr -d "\"")


 echo "Deleting LB"


 curl -X DELETE  -H "Authorization: Bearer $(yc iam create-token)"  \
  -H "Content-Type: application/json" \
  -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers/${LB_ID}"

sleep 15

echo "Deleting TG"


 curl -X DELETE  -H "Authorization: Bearer $(yc iam create-token)"  \
  -H "Content-Type: application/json" \
  -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups/${TARGET_GROUP_ID}"
