# Краткая шпаргалка по созданию профиля yc 

### Профиль yc

При deploy функции используется yc.
Если Вы обратили внимание - то yc идет без дополнительных параметров, все необходимые параметры передаются в профиле, который долэен быть активным.

Создание профиля описано в документации [тут](https://cloud.yandex.ru/docs/cli/cli-ref/managed-yc/config/profile/create)

Посмотрите какие профили у Вас есть:
```bash 
yc config profile list
```

Если профиль уже есть - активируйте его
```bash
yc config profile activate battery
```

Создайте профиль:
```bash
yc config profile create cloud-gayrat-test2
```
Имя для профиля я обычно задаю как "имя облака"-"имя каталога" 

Установите необходимые значения для профиля:

Введите секретный OAUTH token, для его получения нажми ссылку из документации

https://cloud.yandex.ru/docs/cli/quickstart

```bash
yc config set token A**************
yc config set cloud-id b1gib03pgvqrrfvhl3kb
yc config set folder-id b1gku2m6mn7tb2d3ib91
```

Вы можете проверить что Вы ввели в профиль:

```bash
yc config profile get  cloud-gayrat-test2
```

