#!/usr/bin/env bash

if [[ "$DEBUG" == 1 ]]; then
  set -x
  DUMP_FILE=/dev/stderr
else
  DUMP_FILE=/dev/null
fi

export KEY_ID=$1
AAD_CONTEXT=$(echo "$2" | base64)
CIPHERTEXT=$3

export OP="decrypt"
export KMS_HTTP_REQUEST="{\"keyId\": \"$KEY_ID\", \"ciphertext\": \"$CIPHERTEXT\", \"aadContext\": \"$AAD_CONTEXT\"}"

KMS_HTTP_CLIENT=${KMS_HTTP_CLIENT:-"kms-client.sh"}
"$(dirname $0)"/${KMS_HTTP_CLIENT} | tee $DUMP_FILE | jq --raw-output ".plaintext"
