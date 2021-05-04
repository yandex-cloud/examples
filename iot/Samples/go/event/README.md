## Пример работы с mqtt сервером с использованием параметров передаваемых в функцию

Для работы примера нужно создать
[реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry) и
[устройство](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device).

Данный пример выводит полученные сообщения в логи функции.

Для запуска примера необходимо:

1. Создать новую функцию
2. Создать файл: main.go
3. Указать точку входа: main.Handler
4. Создать триггер, который будет вызывать функцию
5. Отправить сообщение ``` {"serial_number":"device1", "temperature":26.32}``` в iot-core
