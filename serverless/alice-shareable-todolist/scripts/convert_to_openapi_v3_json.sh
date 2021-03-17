#!/bin/bash
IN_PATH="$1"
OUT_PATH="$2"
api-spec-converter --from=openapi_3 \
    --to=openapi_3 \
    --syntax=json \
    --order=alpha \
    "${IN_PATH}" > "${OUT_PATH}"
