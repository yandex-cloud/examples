#!/bin/bash

set -xe

DIR=$(dirname $0)

function _fail() {
    echo $0
    exit 1
}
which yc > /dev/null || _fail "Please install yandex cloud CLI, see: https://cloud.yandex.ru/docs/cli/quickstart"

NAME=parrot
yc serverless function create \
   --name  $NAME \
   --description "Example from https://github.com/yandex-cloud/examples/tree/master/serverless/functions/alice/python/parrot"

yc serverless function version create \
   --function-name=$NAME \
   --runtime=python37 \
   --entrypoint=parrot.handler \
   --source-path $DIR/python/parrot/parrot.py	\
   --memory=128M \
   --execution-timeout=3s
