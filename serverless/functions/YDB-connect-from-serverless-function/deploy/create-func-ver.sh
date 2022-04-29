#!/bin/bash
rm -R ./build
rm -R ./dist
mkdir build
source .env

echo "npx tsc --build tsconfig.json"
npx tsc --build tsconfig.json
cp package.json ./dist/package.json

# сделать архив
cd ./dist
rm ../build/func.zip
zip -r ../build/func.zip .
cd ..

echo "yc function version create $FUNCTION_NAME "

yc serverless function version create \
  --function-name=$FUNCTION_NAME \
  --runtime nodejs16 \
  --entrypoint index.handler \
  --memory 256m \
  --execution-timeout 5s \
  --source-path ./build/func.zip \
  --service-account-id=$SERVICE_ACCOUNT_ID \
  --folder-id $FOLDER_ID \
  --environment ENDPOINT=$ENDPOINT,DATABASE=$DATABASE
