#!/bin/bash
# создает версию функции
#cat .env
source .env

echo "Удалить $FUNCTION_NAME"
yc serverless function delete --name=$FUNCTION_NAME

echo "Создать $FUNCTION_NAME"
yc serverless function create --name=$FUNCTION_NAME
echo "сделать функцию публичной"
yc serverless function allow-unauthenticated-invoke $FUNCTION_NAME
