## Пример использования терраформа для деплоя и эмуляции записи от N устойств

Пример создания и разворачивания эмуляции множества устройств, которые умеют
посылать сигнал в mqtt-топики.

В качестве примера, эмулятор выдает сигнал датчика воздуха, измеряющего следующие параметры:
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

Пример представляет собой скрипты для [terraform](https://cloud.yandex.ru/docs/solutions/infrastructure-management/terraform-quickstart#install-terraform).
Они разворачивают в указанном [Яндекс.Облаке](https://cloud.yandex.ru/docs/overview/):
 - [реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#creъate-registry)
 - N [устройств](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device)(см. device_count определен в файле variables.tf)
 - [сервисный аккаунт](https://cloud.yandex.ru/docs/iam/concepts/users/service-accounts) и определеляет необходимые права для него
 - [функцию](https://cloud.yandex.ru/docs/functions/concepts/function), которая записывает во все созданные устройства эмулированное сообщение (топик куда писать определяется в subtopic_for_publish переменой в variables.tf)
 - [триггер](https://cloud.yandex.ru/docs/functions/concepts/trigger), вызывающий функцию с заданным таймаутом (см. publish_cron_expression в variables.tf )
 
 Код функции находится в файле [iot_data.js](publish/iot_data.js)
 
 Для работы примера:
 
 1. *Переопределите переменные token, cloud_id, folder_id
 в файле variables.tf.*
      1. Выполните инициализацию с помощью команды:
         ```
         $ terraform init
         ```

 2. *Проверьте корректность конфигурационных файлов.*
      
      1. Выполните проверку с помощью команды:
         ```
         $ terraform plan
         ```
      Если конфигурация описана верно, в терминале отобразится список создаваемых ресурсов и их параметров.
      Если в конфигурации есть ошибки, Terraform на них укажет. 
         
3. *Разверните облачные ресурсы.*

      1. Если в конфигурации нет ошибок, выполните команду:
         ```
         $ terraform apply
         ```
      2. Подтвердите создание ресурсов.
      
      После этого в указанном каталоге будут созданы все требуемые ресурсы.
      Проверить появление ресурсов и их настройки можно в консоли управления.
      
4. *Для удаления всех созданных ресурсов, выполните команду:*
         ```
         $ terraform destroy
         ```
         
## [Сценарий передачи данных от устройств через Yandex IoT Core в Managed PostgreSql через Serverless функцию](../subscribe_and_postgresql).
