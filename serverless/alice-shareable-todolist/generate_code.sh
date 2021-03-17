#!/bin/bash

set -e

SERVER_SOURCES_DIR=./app/generated/openapi

SPEC_YAML_TEMPLATE=./gateway/openapi-template.yaml
SPEC_JSON_TEMPLATE=./gateway/gen/openapi-template.json
SPEC_FILTERED_V3=./gateway/gen/openapi-filtered.json
SPEC_FILTERED_V2=./gateway/gen/swagger-filtered.json

./scripts/convert_to_openapi_v3_json.sh "${SPEC_YAML_TEMPLATE}" "${SPEC_JSON_TEMPLATE}"
./scripts/filter_function_spec.sh "${SPEC_JSON_TEMPLATE}" "${SPEC_FILTERED_V3}"
./scripts/convert_to_swagger_v2_json.sh "${SPEC_FILTERED_V3}" "${SPEC_FILTERED_V2}"

git rm --ignore-unmatch -rf "${SERVER_SOURCES_DIR}"

mkdir -p "${SERVER_SOURCES_DIR}"
swagger generate server \
    --spec "${SPEC_FILTERED_V2}" \
    --exclude-main \
    --exclude-spec \
    --target "${SERVER_SOURCES_DIR}"

git add "${SERVER_SOURCES_DIR}"

cd frontend
npm run generate-fetcher