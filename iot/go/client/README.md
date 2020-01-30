## Пример работы с mqtt сервером с использованием библиотеки paho.

[Сертификат удостоверяющего
центра](https://storage.yandexcloud.net/mqtt/rootCA.crt) включен в пример
строковым литералом.

Для работы примера нужно создать
[реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry) и
[устройство](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device).

Пример фактически делают эхо, то есть посланное в `$devices/<ID
устройства>/events` приходит в `$registries/<ID устройства>/events` и выводится
на консоль.

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
      |  `- cert.pem
      |  `- key.pem
      `- cert.pem
      `- key.pem

Пример ищет сертификаты относительно current working directory, **поэтому
запускать их нужно в папке с сертификатами** (`my_registry` на схеме).


#### Логин/пароль

Нужно сгенерировать пароль для
[реестра](https://cloud.yandex.ru/docs/iot-core/operations/password/registry-password)
и для
[устройства](https://cloud.yandex.ru/docs/iot-core/operations/password/device-password).
Логины реестра и устройства это их `ID`.
