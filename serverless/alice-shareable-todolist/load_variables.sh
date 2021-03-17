#!/bin/bash

VARIABLES_JSON="./variables.json"

vars=$(cat "$VARIABLES_JSON")
export FOLDER_ID=$(echo "$vars" | jq -r '."folder-id"')
export DOMAIN=$(echo "$vars" | jq -r '."domain"')
export OAUTH_CLIENT_ID=$(echo "$vars" | jq -r '."oauth-client-id"')
export DATABASE=$(echo "$vars" | jq -r '."database"')
export DATABASE_ENDPOINT=$(echo "$vars" | jq -r '."database-endpoint"')
export YC_PROFILE=$(echo "$vars" | jq -r '."yc-profile"')
export SECURE_CONFIG_PATH=$(echo "$vars" | jq -r '."secure-config-path"')
export STORAGE_BUCKET=$(echo "$vars" | jq -r '."storage-bucket"')
export GATEWAY_ID=$(echo "$vars" | jq -r '."gateway-id"')