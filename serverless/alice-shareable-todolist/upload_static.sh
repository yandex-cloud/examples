#!/bin/bash

source ./load_variables.sh
aws --endpoint-url=https://storage.yandexcloud.net     s3 cp --recursive ./frontend/build "s3://${STORAGE_BUCKET}"