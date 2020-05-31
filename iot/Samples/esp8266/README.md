## Пример работы с mqtt сервером для ESP8266 в среде ArduinoIDE с использованием библиотеки [PubSubClient](https://github.com/knolleary/pubsubclient).
[Документация к библиотеке PubSubClient](https://pubsubclient.knolleary.net/)

[Сертификат удостоверяющего
центра](https://storage.yandexcloud.net/mqtt/rootCA.crt) включен в пример
в константы `test_root_ca` в исходном коде.

Для работы примера нужно создать
[реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry) и
[устройство](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device).

В примере показано подключение к Yandex IoT Core, подписка на топик и отправда данных в топик.


#### Настройка ArduinoIDE

1. Нужно указать в настройках в поле "Дополнительные ссылки для менеджера плат" ссылку http://arduino.esp8266.com/stable/package_esp8266com_index.json
2. В менеджере плат установить esp8266
3. В настройках библиотек скетча установить библиотеку PubSubClient (by Nick O'Leary)
4. В настройках скетча выбрать, которую вы будете использовать. Например "NodeMCU 1.0 (ESP-12E Module)"

#### Авторизация

Поддерживаются только один способ авторизации - по паре [логин/пароль](https://cloud.yandex.ru/docs/iot-core/concepts/authorization#log-pass).
[авторизации](https://cloud.yandex.ru/docs/iot-core/concepts/authorization),
сертификаты и логин/пароль.

Нужно сгенерировать пароль для
[реестра](https://cloud.yandex.ru/docs/iot-core/operations/password/registry-password)
и для
[устройства](https://cloud.yandex.ru/docs/iot-core/operations/password/device-password).
Логины реестра и устройства это их `ID`.


#### Как пользоваться

Нужно установить значения следующих переменных

`const char* ssid = "<WifiSSID>";
const char* password = "<WIFIPassword>";
const char* yandexIoTCoredeviceId = "<Yandex IoT Core Cloud Device ID>";
const char* mqttpassword = "<Yandex IoT Core Device pawssword>";`

где 
 - ssid - название сети wifi
 - password - пароль сети wifi
 - yandexIoTCoredeviceId - ID устройства в Yandex IoT Core
 - mqttpassword - пароль, который вы указали для устройства в Yandex IoT Core

Также следует обратить внимание на вызовы

`client.setBufferSize(1024);
client.setKeepAlive(15);`

Первый устанавливает размер буфер для отправки и принятия payload сообщения. Второй указывает период отправки сообщений тарифицируемых PINGREQ. Чем больше период, тем позже ваше устройство обноружит разрыв связи.