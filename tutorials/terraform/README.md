# Terraform configuration files for Yandex Cloud practical guides

## Using hybrid storage

[Using hybrid storage](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage) / [Использование гибридного хранилища](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage)

**Files**:

* [clickhouse-hybrid-storage.tf](./clickhouse-hybrid-storage.tf) — cluster with hybrid storage.

## Sharding tables ClickHouse

[Sharding tables ClickHouse](https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/sharding) / [Шардирование таблиц ClickHouse](https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/sharding)

**Files**:

* [simple-sharding.tf](./clickhouse-sharding/simple-sharding.tf) — cluster with three shards without groups.
* [sharding-with-group.tf](./clickhouse-sharding/sharding-with-group.tf) — cluster with three shards and one shard group which contains `shard1` and `shard2`.
* [advanced-sharding-with-groups.tf](./clickhouse-sharding/advanced-sharding-with-groups.tf) — cluster with three shards and two shard groups. The first group contains `shard1` and `shard2`, the second one contains `shard3`.
