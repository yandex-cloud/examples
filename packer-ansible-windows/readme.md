Установка Yandex.Cloud CLI
https://cloud.yandex.com/en/docs/cli/quickstart#install
```
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```
Инициализация Yandex.Cloud CLI
```
yc init
```
Создайте сервисный аккаунт и передайте его идентификатор в переменную окружения, выполнив команды:
```
$ yc iam service-account create --name <имя пользователя>
$ yc iam key create --service-account-name <имя пользователя> -o service-account.json
$ SERVICE_ACCOUNT_ID=$(yc iam service-account get --name <имя пользователя> --format json | jq -r .id)
```
Назначьте сервисному аккаунту роль admin в каталоге, где будут выполняться операции:
```
$ yc resource-manager folder add-access-binding <имя_каталога> --role admin --subject serviceAccount:$SERVICE_ACCOUNT_ID
```

Получите folder_id из `yc config list`

Заполните файл windows-ansible.json
```
    "folder_id": "<ваш folder_id>",
    "service_account_key_file": "service-account.json",
    "password": "Пароль для Windows",
```
