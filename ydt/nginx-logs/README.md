# Example of YDT and YDS nginx logs integrations

Sample project for parse and delivery nginx log


# Yandex Services
* [Yandex Data Transfer](https://cloud.yandex.ru/services/data-transfer)
* [Yandex Data Stream](https://cloud.yandex.ru/services/yds)
* [Yandex Database](https://cloud.yandex.ru/services/ydb)
* [Cloud Functions](https://cloud.yandex.ru/services/functions)

To setup nginx parser for YDS stream you need: 

# Prepare services

1. Setup nginx delivery into your yds stream
2. Create yandex database for logs storage.
3. Create cloud function for parse nginx log from `index.js` and `package.json` files.

# Prepare transfer

1. Create data transfer source endpoint from stream with created function in data transform section and with JSON converter and `schema.json` file. You may preview your data by clicking preview button.
2. Create data transfer target endpoint for yandex database
3. Create transfer from YDS source to YDB target
4. Activate transfer

# View data

1. Open YDB 
2. Select data from table