#!/usr/bin/env bash

echo "checking lb config"
YC_FOLDER_ID=$(terraform output folder_id | tr  -d "\"")


EXTERNAL_IP=$(curl -X GET --silent  -H "Authorization: Bearer $(yc iam create-token)"   \
  -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/networkLoadBalancers?folderId=${YC_FOLDER_ID}"  \
  | jq .networkLoadBalancers[0].listeners[0].address  |  tr -d "\"")

for i in {1..30}
do
  curl --silent $EXTERNAL_IP
done
