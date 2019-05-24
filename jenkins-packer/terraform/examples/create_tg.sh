#!/usr/bin/env bash

echo "creating TG"
YC_FOLDER_ID=$(terraform output folder_id | tr  -d "\"")

cat > create-tg.json <<EOF
{
    "folderId": "${YC_FOLDER_ID}",
    "name": "yc-auto-tg",
    "regionId": "ru-central1"
}
EOF


curl -X POST \
  -H "Authorization: Bearer $(yc iam create-token)" \
	-H "Content-Type: application/json" \
	-k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups" \
  -d @create-tg.json

rm -rf create-tg.json


TARGET_GROUP_ID=$(curl -X GET  --silent -H "Authorization: Bearer $(yc iam create-token)"  \
 -H "Content-Type: application/json" \
 -k "https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups?folderId=${YC_FOLDER_ID}"  | jq .targetGroups[0].id | tr -d "\"")

SUBNET_ID_LIST=$(terraform output subnet_ids)
SUBNET_ID_LIST=($(echo "$SUBNET_ID_LIST" | tr ',' '\n'))
INTERNAL_ADDRESS_LIST=$(terraform output internal_ip_addresses)
INTERNAL_ADDRESS_LIST=($(echo "$INTERNAL_ADDRESS_LIST" | tr ',' '\n'))



for i in ${!INTERNAL_ADDRESS_LIST[@]}; do



  SUBNET_ID=${SUBNET_ID_LIST[$i]}
  INTERNAL_ADDRESS=${INTERNAL_ADDRESS_LIST[$i]}
  echo "adding  $INTERNAL_ADDRESS to target group"
  cat > add_real.json <<EOF
  {
    "targets":
    [
      {
        "subnetId": "${SUBNET_ID}",
        "address": "${INTERNAL_ADDRESS}"
      }
    ]
  }
EOF

  curl -X POST \
    -H "Authorization: Bearer $(yc iam create-token)" \
  	-H "Content-Type: application/json" \
    -k https://load-balancer.api.cloud.yandex.net/load-balancer/v1alpha/targetGroups/${TARGET_GROUP_ID}:addTargets \
    -d @add_real.json

  sleep 2
done

rm -rf add_real.json
