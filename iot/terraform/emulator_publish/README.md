## Пример использования терраформа для деплоя и эмуляции записи от N устойств

Пример создания и разворачивания эмуляции множества устройств, которые умеют
посылать сигнал в mqtt-топики.

Пример представляет собой скрипты для [terraform](https://cloud.yandex.ru/docs/solutions/infrastructure-management/terraform-quickstart#install-terraform)
разворачивает в указанном [Яндекс.Облаке](https://cloud.yandex.ru/docs/overview/)

 [реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry),
 
 N [устройств](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device)
 (см. device_count определен в файле variables.tf),
  
 [сервисный аккаунт](https://cloud.yandex.ru/docs/iam/concepts/users/service-accounts)
 и определеляет необходимые права для него,
 
 [функцию](https://cloud.yandex.ru/docs/functions/concepts/function),
 которая записывает во все созданные устройства эмулированное сообщение заданным
 (топик куда писать определяется в subtopic_for_publish переменой в variables.tf),
 
 [триггер](https://cloud.yandex.ru/docs/functions/concepts/trigger),
 вызывающий функцию с заданным таймаутом (см. publish_cron_expression в variables.tf ),
 
 1. *Для работы примера нужно переопределить переменные token, cloud_id, folder_id
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