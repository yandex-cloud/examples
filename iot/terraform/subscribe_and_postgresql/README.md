# Сценарий передачи данных IoT платформы Яндекс в Managed PostgreSql через Serverless функцию (IoTCoreAdapter). 
Сценарий состоит из:
<ol>
<li>Python-скрипта с кодом функции <a href='https://github.com/yandex-cloud/examples/tree/master/iot/terraform/subscribe_and_postgresql/iotadapter.py'>iotadapter.py</li>
<li>Скриптов для terraform, которые разворачивают в указанном <a href=https://cloud.yandex.ru/docs/overview/>Яндекс.Облаке</a> необходимые для работы примера сервисы:
  <div>- <a href=https://cloud.yandex.ru/docs/managed-postgresql/>Managed PostgreSql database</a><div>
  <div>- <a href=https://cloud.yandex.ru/docs/iot-core/>IoT Core</a> реестр с IoT устройством</div>
  <div>- <a href=https://cloud.yandex.ru/docs/functions/>Cloud function</a> и триггеры для сохранения сообщений из сервиса IoT Core в PostgreDatabase</div>
</li> 
</ol>
Для работы примера нужно:
<ol>
  <li>Переименовать файл terraform.example.tfvars в terraform.tfvars</li>
  <li>В файле terraform.tfvars перереопределить переменные yc_cloud_id, yc_folder_id, yc_main_zone в соотв. с настройками Вашего тенанта.</li>
<li>Выполнить инициализацию с помощью команды:
<pre><code>$ terraform init
</code></pre>
</li>
<li>
<p><em>Проверить корректность конфигурационных файлов с помощью команды:.</em></p>
<pre><code>$ terraform plan
</code></pre>
</li>
<li>
<p>Если конфигурация описана верно, в терминале отобразится список создаваемых ресурсов и их параметров.
  Если в конфигурации есть ошибки, Terraform на них укажет.</p>
</li>
<li><p>Развернуть облачные ресурсы.</p>
  <div><em> Если в конфигурации нет ошибок, выполните команду:</em></div>
<pre><code>$ terraform apply
</code></pre>
</li>
<li>Подтвердить создание ресурсов.</li>
<li>
<p>После этого в указанном каталоге будут созданы все требуемые ресурсы.</p>
<p>Так же приложение выдаст идентификаторы и пароли созданных IoT устройств, реестра, кластера БД.</p>
</li>
<li>
<p>Для удаления всех созданных ресурсов, выполните команду:</p>
<p><code>$ terraform destroy</code></p>
</li>
</ol>
<h2>Дополнительная информация:<h2>
  <p><a href='https://github.com/yandex-cloud/examples/tree/master/iot/terraform/emulator_publish'>Пример использования терраформа для деплоя и эмуляции записи от N устойств</a></p>
