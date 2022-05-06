# Terraform configuration files for Yandex Cloud practical guides

All files contains the following resources:

* Network
* Subnets
* Security groups
* Rules for security groups

## Getting data from RabbitMQ

[Getting data from RabbitMQ](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq) / [Получение данных из RabbitMQ](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq)

**Files**:

* [clickhouse-cluster-and-vm-for-rabbitmq.md](./clickhouse-cluster-and-vm-for-rabbitmq.md) — Yandex Managed Service for ClickHouse cluster and VM for RabbitMQ

## Using hybrid storage for Yandex Managed Service for ClickHouse cluster

[Using hybrid storage](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage) / [Использование гибридного хранилища](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage).

**Files**:

* [clickhouse-hybrid-storage.tf](./clickhouse-hybrid-storage.tf) — Yandex Managed Service for ClickHouse cluster with a hybrid storage.

## Getting data from Yandex Managed Service for Apache Kafka

[Getting data from Managed Service for Apache Kafka](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-mkf) / [Получение данных из Managed Service for Apache Kafka](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-mkf)

**Files**:

* [data-from-kafka-to-clickhouse.tf](./data-from-kafka-to-clickhouse/data-from-kafka-to-clickhouse.tf) — Yandex Managed Service for Apache Kafka® cluster and Yandex Managed Service for ClickHouse cluster.

## Using Yandex Managed Service for Redis clusters as PHP session storage

[Using Managed Service for Redis clusters as PHP session storage](https://cloud.yandex.com/en/docs/managed-redis/tutorials/redis-as-php-sessions-storage) / [Использование кластера Managed Service for Redis в качестве хранилища сессий PHP](https://cloud.yandex.ru/docs/managed-redis/tutorials/redis-as-php-sessions-storage)

**Files**:

* [redis-as-php-session-storage/redis-cluster-non-sharded-and-vm.tf](./redis-cluster-non-sharded-and-vm.tf) — non-sharded Yandex Managed Service for Redis cluster and VM.
* [redis-as-php-session-storage/redis-cluster-sharded-and-vm.tf](./redis-cluster-non-sharded-and-vm.tf) — sharded Yandex Managed Service for Redis cluster and VM.

## Creating a PostgreSQL cluster for 1C:Enterprise

[Creating a PostgreSQL cluster for 1C:Enterprise](https://cloud.yandex.com/en-ru/docs/managed-postgresql/tutorials/1c-postgresql) / [Создание кластера PostgreSQL для «1С:Предприятия»](https://cloud.yandex.ru/docs/managed-postgresql/tutorials/1c-postgresql)

**Files**:

* [postgresql-1c.tf](./postgresql-1c.tf) — Yandex Managed Service for PostgreSQL cluster for 1С:Enterprise
