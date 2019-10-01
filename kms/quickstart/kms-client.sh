#!/usr/bin/env bash

if [[ "$DEBUG" == 1 ]]; then
  set -x
fi

IAM_TOKEN=${IAM_TOKEN:-$(yc iam create-token)}
KMS_HTTP_ENDPOINT=${KMS_HTTP_ENDPOINT:-"https://kms.yandex:443"}

curl -s \
    -H "Authorization: Bearer ${IAM_TOKEN}" \
    -H "Content-type: application/json" \
    --data "${KMS_HTTP_REQUEST}" \
    "${KMS_HTTP_ENDPOINT}/kms/v1/keys/${KEY_ID}:${OP}"
