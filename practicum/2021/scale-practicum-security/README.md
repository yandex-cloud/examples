# Настройка окружения для практикума «Сбор, мониторинг и анализ логов в Yandex Managed Service for Elasticsearch»

## Обязательные требования перед workshop
Убедитесь, что вы получили по почте тестовую учетную запись в облаке, и установите следующее по:

- :white_check_mark: установить и настроить [yc client](https://cloud.yandex.ru/docs/cli/quickstart)
- :white_check_mark: установить и настроить [git](https://git-scm.com/book/ru/v2/Введение-Установка-Git)
- :white_check_mark: установить [terraform](https://www.terraform.io/downloads.html)
- :white_check_mark: установить [jq](https://macappstore.org/jq/)
- :white_check_mark: установить [helm](https://helm.sh/docs/intro/install/)


Ниже описаны шаги для их установки на различных операционных системах.

### Windows
- [Установите WSL](https://docs.microsoft.com/en-us/windows/wsl/install)
- Запустите Ubuntu Linux
- Настройте согласно инструкции для Ubuntu Linux

### Ubuntu Linux

В случае Linux отличного от Ubuntu, установите те же пакеты, используя пакетный менеджер вашего дистрибутива.

#### yc CLI

Установите [yc CLI](https://cloud.yandex.ru/docs/cli/operations/install-cli#interactive)
```bash
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec -l $SHELL
yc version
```

#### terraform

[Установите `terraform`](https://learn.hashicorp.com/tutorials/terraform/install-cli) версии не ниже `1.0.8`:
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform -y
terraform version
```

Установите прочие пакеты:
```bash
sudo apt-get install jq curl git -y
```

Установите [helm](https://helm.sh/docs/intro/install/)

```
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

### macOS

Установите [yc CLI](https://cloud.yandex.ru/docs/cli/operations/install-cli#interactive)
```bash
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec -l $SHELL
yc version
```

[Установите `brew`](https://brew.sh):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
# terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version

# Прочее
brew install jq curl git helm
```
