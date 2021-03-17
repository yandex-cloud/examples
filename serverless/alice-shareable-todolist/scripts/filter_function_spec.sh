#!/bin/bash
IN_PATH="$1"
OUT_PATH="$2"
# filters OpenAPI spec, leaving only resources with functions integration
cat "${IN_PATH}" | jq '.paths |= map_values(map_values(select(."x-yc-apigateway-integration".type == "cloud_functions")) | select(length > 0))' > "${OUT_PATH}"