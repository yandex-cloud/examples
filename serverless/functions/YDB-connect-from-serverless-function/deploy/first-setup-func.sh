#!/bin/sh
pwd
export $(grep -v '^#' main.env | xargs -d '\n')

echo "Удалить $FUNCTION_NAME"
yc serverless function delete --name=$FUNCTION_NAME

echo "Создать $FUNCTION_NAME"
yc serverless function create --name=$FUNCTION_NAME
echo "сделать функцию публичной $FUNCTION_NAME"
yc serverless function allow-unauthenticated-invoke $FUNCTION_NAME  --folder-id $FOLDER_ID
echo "Просмотр разрешений $FUNCTION_NAME"
yc serverless function list-access-bindings $FUNCTION_NAME

echo "Отобразить FUNCTION_ID для функции $FUNCTION_NAME "
export FUNCTION_ID=`yc serverless function get --name=$FUNCTION_NAME --format json --folder-id=$FOLDER_ID | jq -r '.id'`
echo "ID функции для запуска $FUNCTION_ID"
echo "FUNCTION_ID=$FUNCTION_ID" >funcid.env

echo "Сформировать файл .env"
pwd
cat main.env funcid.env > .env

rm -R ./dist


