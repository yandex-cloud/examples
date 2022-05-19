1. Если у вас еще нет {{ TF }}, [установите его](../../tutorials/infrastructure-management/terraform-quickstart.md#install-terraform).
        1. Скачайте [файл с настройками провайдера](https://github.com/yandex-cloud/examples/tree/master/tutorials/terraform/provider.tf). Поместите его в отдельную рабочую директорию и [укажите значения параметров](../../tutorials/infrastructure-management/terraform-quickstart.md#configure-provider).
        1. Скачайте в ту же рабочую директорию файл конфигурации кластера [k8s-cluster.tf](https://github.com/yandex-cloud/examples/tree/master/tutorials/terraform/managed-kubernetes/k8s-cluster.tf).

            В файле описаны:

            * сеть;
            * подсеть;
            * группа безопасности по умолчанию и правила, необходимые для работы кластера:
                * правила для служебного трафика;
                * правила для доступа к API {{ k8s }} и управления кластером с помощью `kubectl` (через порты 443 и 6443);
            * кластер {{ managed-k8s-name }};
            * сервисный аккаунт, необходимый для создания кластера и группы узлов {{ managed-k8s-name }}.

        1. Укажите в файле конфигурации [идентификатор каталога](../../resource-manager/operations/folder/get-id.md).

        1. Выполните команду `terraform init` в директории с конфигурационными файлами. Эта команда инициализирует провайдеров, указанных в конфигурационных файлах, и позволяет работать с ресурсами и источниками данных провайдера.
        1. Проверьте корректность файлов конфигурации {{ TF }} с помощью команды:

            ```bash
            terraform validate
            ```

            Если в файлах конфигурации есть ошибки, {{ TF }} на них укажет.

        1. Создайте необходимую инфраструктуру:

            {% include [terraform-apply](../../mdb/terraform/apply.md) %}

            {% include [explore-resources](../../mdb/terraform/explore-resources.md) %}
