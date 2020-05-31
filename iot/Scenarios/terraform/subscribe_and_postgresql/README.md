## Сценарий передачи данных от устройств через Yandex IoT Core в Managed PostgreSql через Serverless функцию. 

В качестве примера, используется сигнал датчика воздуха, измеряющего следующие параметры:
 - Температура
 - Влажность
 - Давление
 - Уровень содержания СO2

Датчик выдает результат в формате JSON. Например:
```
   {
    "DeviceId":"0e3ce1d0-1504-4325-972f-55c961319814",
    "TimeStamp":"2020-05-21T22:53:16Z",
    "Values":[
        {"Type":"Float","Name":"Humidity","Value":"25.281837"},
        {"Type":"Float","Name":"CarbonDioxide","Value":"67.96608"},
        {"Type":"Float","Name":"Pressure","Value":"110.7021"},
        {"Type":"Float","Name":"Temperature","Value":"127.708824"}
        ]
   }
```

Сценарий состоит из:
 - Python-скрипта с кодом функции [iotadapter.py](iotadapter.py)
 - Скриптов для terraform, которые разворачивают в указанном [Яндекс.Облаке](https://cloud.yandex.ru/docs/overview/) необходимые для работы примера сервисы:
   - [Yandex Managed Service for PostgreSQL](https://cloud.yandex.ru/docs/managed-postgresql)
   - [Yanxex IoT Core](https://cloud.yandex.ru/docs/iot-core)
   - [Yandex Cloud Functions](https://cloud.yandex.ru/docs/functions/) и триггеры для сохранения сообщений из сервиса IoT Core в PostgreDatabase</div>

Для работы примера нужно:
 - Переименовать файл terraform.example.tfvars в terraform.tfvars
 - В файле terraform.tfvars перереопределить переменные yc_cloud_id, yc_folder_id, yc_main_zone в соотв. с настройками Вашего Облака
 - Выполнить инициализацию с помощью команды `$ terraform init`
 - Проверить корректность конфигурационных файлов с помощью команды: `$ terraform plan`
   Если конфигурация описана верно, в терминале отобразится список создаваемых ресурсов и их параметров.
   Если в конфигурации есть ошибки, Terraform на них укажет.
 - Развернуть облачные ресурсы командой: `$ terraform apply`
 

После этого в указанном каталоге будут созданы все требуемые ресурсы.
Так же приложение выдаст идентификаторы и пароли созданных IoT устройств, реестра, кластера БД.

Для удаления всех созданных ресурсов, выполните команду `$ terraform destroy`

## [Пример использования терраформа для деплоя и эмуляции записи от N устойств](../emulator_publish). 
