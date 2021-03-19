# Руководство по развертыванию небольшого ToDo-list'а на серверлесс стеке при помощи Java Servlet API

1. Заводим `serverless` базу данных. 
Для этого в списке сервисов находим `Yandex Database`, нажимаем Создать базу данных, тип базы данных выбираем `serverless`, 
далее переходим во вкладку Навигация и создаем таблицу Tasks. Это можно сделать либо из UI, либо простым SQL-запросом:

    ```sql
    create table Tasks (
        TaskId Utf8,
        Name Utf8,
        Description Utf8,
        CreatedAt Datetime,
        primary key (TaskId)
    );
    ```

2. Заводим в текущей директории сервисный аккаунт (для этого переходим в корень директории и слева в меню выбираем Сервисные аккаунты),
после чего добавляем ему права `viewer` и `editor`

3. Создаем три функции (по одной на каждый сервлет), заливаем в каждую из них данный проект, указываем среду исполнения `java11` и точку входа, в зависимости от текущего сервлета. 
**Обязательно** указываем сервисный аккаунт, созданный в предыдущем пункте. Каждой функции в переменные окружения добавляем:
    * `DATABASE` - значение поля `База данных` вашей базы данных (например, /ru-centralx/yyyyyyyyyy/zzzzzzzzzz)
    * `ENDPOINT` - значение поля `Эндпоинт` вашей базы данных (например, ydb.serverless.yandexcloud.net:2135)

    Должны получиться функции с такими точками входа:
    * yandex.cloud.examples.serverless.todo.AddTaskServlet
    * yandex.cloud.examples.serverless.todo.ListTasksServlet
    * yandex.cloud.examples.serverless.todo.DeleteTaskServlet

    Чтобы задеплоить функцию, нужно:
    * Заархивировать содержимое проекта (например, `zip target.zip -r src pom.xml`)
    * Исполнить простую команду (должна быть установлена и настроена утилита `yc`, подробнее читать [здесь](https://cloud.yandex.ru/docs/cli/quickstart#install))
    
   ```bash
    yc serverless function version create \
        --function-id=<текущий id функции> \
        --runtime=java11 \
        --entrypoint=<текущая точка входа> \
        --memory=128mb \
        --execution-timeout=3s \
        --source-path=target.zip \
        --environment="DATABASE=<значение поля База данных>;ENDPOINT=<значение поля Эндпоинт>"
    ```
   
    Команду необходимо выполнить 3 раза, каждый раз подставляя одну из точек входа,
    id соответствующей ей функции и значения переменных окружения.
    * ИЛИ создать версию через UI, для этого нужно зайти в функцию, 
    открыть вкладку Редактор, во вкладке Способ выбрать `ZIP`, залить туда архив с проектом.
    Затем проставить параметры:
      * Точка входа: текущая точка входа (например, `yandex.cloud.examples.serverless.todo.AddTaskServlet` для функции, которая отвечает за этот сервлет)
      * Таймаут, c: 3
      * Память: 128 МБ
      * Сервисный аккаунт: выбрать сервисный аккаунт, созданный в пункте 2
      * Переменные окружения:
        * DATABASE: значение поля `База данных`
        * ENDPOINT: значение поля `Эндпоинт`

4. Создаем бакет в `s3`, заливаем туда `index.html` (находится в `src/main/resources/index.html`)

5. Создаем `API Gateway`, в поле `paths` спецификации стираем все содержимое, пишем туда:

    ```openapi
      /:
        get:
          x-yc-apigateway-integration:
            type: object-storage
            bucket: <bucket>
            object: index.html
            presigned_redirect: false
            service_account: <service_account>
          operationId: static
      /add:
        post:
          x-yc-apigateway-integration:
            type: cloud-functions
            function_id: <add_servlet_function>
          operationId: addTask
      /list:
        get:
          x-yc-apigateway-integration:
            type: cloud-functions
            function_id: <list_servlet_function>
          operationId: listTasks
      /delete:
        delete:
          x-yc-apigateway-integration:
            type: cloud-functions
            function_id: <delete_servlet_function>
          operationId: deleteTask
    ```
    
    Здесь вместо `<bucket>` пишем имя бакета, в котором лежит файл `index.html`, вместо `<service_account>` id сервисного аккаунта, созданного в пункте 2. А вместо остальных параметров id соответствующих функций

Готово! Теперь при переходе по ссылке, указанной в `API Gateway` должен отобразиться ваш ToDo-list

Полезные ссылки:
* [Документация Cloud Functions](https://cloud.yandex.ru/docs/functions/)
* [Документация YDB](https://cloud.yandex.ru/docs/ydb/)
* [Документация API Gateway](https://cloud.yandex.ru/docs/api-gateway/)