#!/bin/bash
source ./load_variables.sh
IAM_TOKEN=$(yc --profile "${YC_PROFILE}" iam create-token) ydb -e "${DATABASE_ENDPOINT}" -d "${DATABASE}" scripting yql -f ./schema/schema.sql