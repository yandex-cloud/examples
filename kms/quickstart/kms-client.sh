#!/usr/bin/env bash

if [[ "$DEBUG" == 1 ]]; then
  set -x
fi

MEDATADA_ADDRESS=169.254.169.254
GCE_SERVICE_ACCOUNT_PATH=computeMetadata/v1/instance/service-accounts/default/token
SA_TOKEN_URL=$MEDATADA_ADDRESS/$GCE_SERVICE_ACCOUNT_PATH
GCE_HEADERS='-H "Metadata-Flavor: Google"'
SA_IAM_TOKEN=$(curl --connect-timeout 1 -s $GCE_HEADERS $SA_TOKEN_URL | jq ".access_token" -r)
if [ -z "$SA_IAM_TOKEN" ]; then
  IAM_TOKEN=${IAM_TOKEN:-$(yc iam create-token)}
else
  IAM_TOKEN=${IAM_TOKEN:-$SA_IAM_TOKEN}
fi
IAM_TOKEN=${IAM_TOKEN:-$(yc iam create-token)}
KMS_HTTP_ENDPOINT=${KMS_HTTP_ENDPOINT:-"https://kms.yandex:443"}

curl -s \
    -H "Authorization: Bearer ${IAM_TOKEN}" \
    -H "Content-type: application/json" \
    --data "${KMS_HTTP_REQUEST}" \
    "${KMS_HTTP_ENDPOINT}/kms/v1/keys/${KEY_ID}:${OP}"
