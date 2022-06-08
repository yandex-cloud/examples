# Авторизация в Yandex database c помощью сервиса метаданных.

# Документация
[Авторизация в YDB CLI](https://cloud.yandex.ru/docs/ydb/concepts/connect)

## Где работает сервис метаданных
Сервис метаданных работает на виртуальных машинах внутри Yandex compute cloud, а также в serverless функциях Yandex

## Данный пример представляет собой отдельный проект по развертыванию NodeJS serverless функции

Для запуска Вам необходимо:

1. клонировать репозитарий
2. установить зависимости командой npm i
3. внесите Ваши данные в .env (
 
   ENDPOINT=grpcs://ydb.serverless.yandexcloud.net:2135
   возьмите из окна свойств Вашей базы данных
   DATABASE=/ru-central1/b1gu1b9o1gq4ptfngmvq/etnj5859gt3uqe803bls
   FUNCTION_NAME=func-test-ydb
   перейдите в Ваше облако и вставьте id folder
   FOLDER_ID=b1ga2r8ll8h12977etbg
   создайте сервисный account, дайте ему права admin   SERVICE_ACCOUNT_ID=ajeb5ab25igcdquppgpu
   имя файла в котором записаны секретные ключи 
   SA_KEY_FILE=service_account_key_file.json

 Эти данные Вы можете взять из окна свойств Вашей базы данных

![картинка с примером данных из asserts](./asserts/2021-12-09_16-14-46.png)

Для создания авторизованного ключа для сервисного аккаунта воспользуйтесь документацией: [Ссылка](https://cloud.yandex.ru/docs/iam/operations/authorized-key/create)

Настройте профиль yc и запустите команду:
```
yc iam key create --service-account-name my-robot -o service_account_key_file.json
```

my-robot - это имя Вашего сервисного аккаунта, который должен иметь полный доступ к базе.

Файл service_account_key_file.json должен лежать в корне проекта.


4. следуйте инструкциям в deploy/deploy.md для deploy функции
5. вызовите функцию передав ей параметр api_key - имя таблицы, которая будет создана

Обратите внимание что данный шаблон подразумевает отладку кода на локальном компьютере. Для этого для старта программы используйте файл index-local.ts и проведите отладку Вашего кода.


Пример на python
https://cloud.yandex.ru/docs/functions/solutions/connect-to-ydb#create-function
