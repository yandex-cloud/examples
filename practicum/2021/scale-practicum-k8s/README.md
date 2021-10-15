# Настройка окружения для практикума Безопасный и быстрый деплой в Kubernetes®

Для работы вам потребуются:
```
yc (Yandex Cloud CLI)
terraform >= 1.0.8
kubectl >= 1.20
docker
jq
curl
git
```

Ниже описаны шаги для их установки на различных операционных системах.

### Виртуальная машина

Можно не устанавливать все зависимости на свой компьютер, а работать из преднастроенной виртуальной машины. В таком
случае установите [yc CLI](https://cloud.yandex.ru/docs/cli/operations/install-cli#interactive). Если у вас ещё нет пары
ssh ключей, то [создайте её](https://cloud.yandex.ru/docs/compute/operations/vm-connect/ssh#creating-ssh-keys).

На первом этапе практикума, будет показано как создать виртуальную машину и зайти на неё по SSH.

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

#### docker

[Установите `docker`](https://docs.docker.com/engine/install/ubuntu/):
```bash
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sudo docker run hello-world
```

[Настройте запуск docker без sudo](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user)
```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

Предзагрузите образ `aws-cli`:
```bash
docker pull amazon/aws-cli
```

#### Прочее

[Установите `terraform`](https://learn.hashicorp.com/tutorials/terraform/install-cli) версии не ниже `1.0.8`:
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform -y
terraform version
```

[Установите `kubectl` версии не ниже `1.20`](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux):
```bash
curl -LO https://dl.k8s.io/release/v1.22.0/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version
```

Установите прочие пакеты:
```bash
sudo apt-get install jq curl git -y
```

### macOS

Установите [yc CLI](https://cloud.yandex.ru/docs/cli/operations/install-cli#interactive)
```bash
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec -l $SHELL
yc version
```

[Установите docker](https://docs.docker.com/desktop/mac/install/)
Предзагрузите образ aws-cli:
```bash
docker pull amazon/aws-cli
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


# kubectl
brew install kubectl 
kubectl version

# Прочее
brew install jq curl git
```










