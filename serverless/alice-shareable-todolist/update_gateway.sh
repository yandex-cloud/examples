#!/bin/bash

set -e

source ./load_variables.sh
tf_out=$(terraform output -json)

export GATEWAY_SA_ID=$(echo "${tf_out}" | jq -r '."gateway-sa-id".value')
export WEB_FUNCTION_ID=$(echo "${tf_out}" | jq -r '."function-web-id".value')

TEMPLATE_FILE="./gateway/openapi-template.yaml"
DIST_FILE="./dist/gateway-spec.yaml"

cat "$TEMPLATE_FILE" | envsubst '${GATEWAY_SA_ID}${WEB_FUNCTION_ID}${STORAGE_BUCKET}' > "$DIST_FILE"

yc --profile "${YC_PROFILE}" serverless api-gateway update "$GATEWAY_ID" --spec "$DIST_FILE"