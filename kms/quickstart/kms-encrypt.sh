#!/usr/bin/env bash

if [[ "$DEBUG" == 1 ]]; then
  set -x
  DUMP_FILE=/dev/stderr
else
  DUMP_FILE=/dev/null
fi


export KEY_ID=$1
AAD_CONTEXT=$(echo $2 | base64)
PLAINTEXT=$(echo $3)

export OP="encrypt"
export KMS_HTTP_REQUEST="{\"keyId\": \"$KEY_ID\", \"plaintext\": \"$PLAINTEXT\", \"aadContext\": \"$AAD_CONTEXT\"}"

KMS_HTTP_CLIENT=${KMS_HTTP_CLIENT:-"kms-client.sh"}
$(dirname $0)/${KMS_HTTP_CLIENT} | tee $DUMP_FILE | jq --raw-output ".ciphertext"
