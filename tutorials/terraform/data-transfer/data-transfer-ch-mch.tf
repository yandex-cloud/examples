# Infrastructure for the Yandex Cloud Managed Service for ClickHouse cluster and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/data-migration
#
# Set source and target clusters settings.
locals {
  # Source ClickHouse server settings:
  source_user    = ""   # Set the source ClickHouse server username.
  source_db_name = ""   # Set the source ClickHouse server database name.
  source_pwd     = ""   # Set the source ClickHouse server password.
  source_host    = ""   # Set the source ClickHouse server IP address or FQDN.
  source_port    = 9000 # Set the source ClickHouse server port number that Data Transfer will use for connections.
  # Target cluster settings:
  target_clickhouse_version = "" # Set the ClickHouse version.
  target_user               = "" # Set the target cluster username.
  target_password           = "" # Set the target cluster password.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for ClickHouse cluster"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = local.source_port
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  name               = "clickhouse-cluster"
  description        = "Managed Service for ClickHouse cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = 10 # GB
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = "yandex_vpc_subnet.subnet-a.id"
  }

  database {
    name = local.source_db_name
  }

  user {
    name     = local.target_user
    password = local.target_password
    permission {
      database_name = local.target_db_name
      roles         = ["ALL"]
    }
  }
}

resource "yandex_datatransfer_endpoint" "clickhouse-source" {
  description = "Source endpoint for ClickHouse server"
  name        = "clickhouse-source"
  settings {
    clickhouse_source {
      connection {
        on_premise {
          hosts = [local.source_host]
          port  = local.source_port
        }
      }
      database = local.source_db_name
      user     = local.source_user
      password {
        raw = local.source_pwd
      }
    }
  }
}

resource "yandex_datatransfer_endpoint" "managed-clickhouse-target" {
  description = "Target endpoint for the Managed Service for ClickHouse cluster"
  name        = "managed-clickhouse-target"
  settings {
    clickhouse_target {
      connection {
        mdb_cluster_id = yandex_mdb_clickhouse_cluster.clickhouse-cluster.id
      }
      database = local.source_db_name
      user     = local.target_user
      password {
        raw = local.target_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "clickhouse-transfer" {
  description = "Transfer from ClickHouse server to the Managed Service for ClickHouse cluster"
  name        = "transfer-from-onpremise-clickhouse-to-managed-clickhouse"
  source_id   = yandex_datatransfer_endpoint.clickhouse-source.id
  target_id   = yandex_datatransfer_endpoint.managed-clickhouse-target.id
  type        = "SNAPSHOT_ONLY" # Copy all data from the source server.
}
