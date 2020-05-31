## Пример работы с mqtt сервером с использованием библиотеки paho.
[Установка библиотеки paho](https://github.com/eclipse/paho.mqtt.python)

`pip install paho-mqtt`

[Сертификат удостоверяющего
центра](https://storage.yandexcloud.net/mqtt/rootCA.crt) включен в пример
в виде файла на диске rootCA.crt.

Для работы примера нужно создать
[реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry) и
[устройство](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device).

Пример фактически делают эхо, то есть посланное в `$devices/<ID
устройства>/events` возвращается клиенту посредством подписки на этот топик
от имени реестра и выводится на консоль.

Поддерживаются два спосба
[авторизации](https://cloud.yandex.ru/docs/iot-core/concepts/authorization),
сертификаты и логин/пароль.


#### Сертификаты

В примере используются два
[сертификата](https://cloud.yandex.ru/docs/iot-core/quickstart#create-ca) - один
для устройства, один для реестра.

Расположение на диске:

    certs structure:
      /my_registry        Registry directory |currentDir|. Run samples from here.
      `- /device          Concrete device cert directory.
      |  `- dev.crt
      |  `- dev.key
      `- reg.crt
      `- reg.key

Пример ищет сертификаты относительно current working directory, **поэтому
запускать их нужно в папке с сертификатами** (`my_registry` на схеме).


#### Логин/пароль

Нужно сгенерировать пароль для
[реестра](https://cloud.yandex.ru/docs/iot-core/operations/password/registry-password)
и для
[устройства](https://cloud.yandex.ru/docs/iot-core/operations/password/device-password).
Логины реестра и устройства это их `ID`.
