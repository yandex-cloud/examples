# Terraform configuration files for Yandex Cloud practical guides

File with provider settings / Файл с настройками провайдера: [provider.tf](./provider.tf)

## Managed Service for ClickHouse

### Using hybrid storage

[Using hybrid storage](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage) / [Использование гибридного хранилища](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage)

**Files**:

* [clickhouse-hybrid-storage.tf](./clickhouse-hybrid-storage.tf)
    Terraform-конфигурация кластера с гибридным хранилищем.

### Sharding tables ClickHouse

[Sharding tables ClickHouse](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/sharding) / [Шардирование таблиц ClickHouse](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/sharding)

**Files**:

* [simple-sharding.tf](./simple-sharding.tf)
    Cluster with three shards without groups.
* [sharding-with-group.tf](./sharding-with-group.tf)
    Cluster with three shards and one shard group which contains `shard1` and `shard2`.
* [advanced-sharding-with-groups.tf](./advanced-sharding-with-groups.tf)
    Cluster with three shards and two shard groups. The first contains `shard1`, the second contains `shard2` and `shard3`.

### Creating a PostgreSQL cluster for 1C:Enterprise

[Creating a PostgreSQL cluster for 1C:Enterprise](https://cloud.yandex.com/en-ru/docs/managed-postgresql/tutorials/1c-postgresql) / [Создание кластера PostgreSQL для «1С:Предприятия»](https://cloud.yandex.ru/docs/managed-postgresql/tutorials/1c-postgresql)

**Files**:

* [postgresql-1c.tf](./postgresql-1c.tf) Cluster for 1c.
