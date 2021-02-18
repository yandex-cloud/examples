# Руководство по развертыванию небольшого ToDo-list'а на серверлесс стеке при помощи Java Servlet API

1. Заводим `serverless` базу данных. Создаем таблицу Tasks:

```sql
create table Tasks (
    TaskId Utf8,
    Name Utf8,
    Description Utf8,
    CreatedAt Datetime,
    primary key (TaskId)
);
```

2. Заводим в облаке сервисный аккаунт, даем ему права `viewer` и `editor`

3. Создаем три функции (по одной на сервлет), заливаем в каждую из них данный проект, указываем среду исполнения `java11` и точку входа, в зависимости от текущего сервлета. 
**Обязательно** указываем сервисный аккаунт, созданный в предыдущем пункте. Каждой функции в переменные окружения добавляем:
* `DATABASE` - значение поля `База данных` вашей базы данных (например, /ru-centralx/yyyyyyyyyy/zzzzzzzzzz)
* `ENDPOINT` - значение поля `Эндпоинт` вашей базы данных (например, ydb.serverless.yandexcloud.net:2135)
Должны получиться функции с такими точками входа:
* org.buraindo.todo.AddTaskServlet
* org.buraindo.todo.ListTasksServlet
* org.buraindo.todo.DeleteTaskServlet

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