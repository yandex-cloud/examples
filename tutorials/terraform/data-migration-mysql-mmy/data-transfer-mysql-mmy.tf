# Infrastructure for the Yandex Cloud Managed Service for MySQL cluster and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/managed-mysql/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-mysql/tutorials/data-migration
#
# Set source and target clusters settings.
locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  # Source cluster settings:
  source_user    = ""   # Set the source cluster username.
  source_db_name = ""   # Set the source cluster database name.
  source_pwd     = ""   # Set the source cluster password.
  source_host    = ""   # Set the source cluster master host IP address or FQDN.
  source_port    = 3306 # Set the source cluster port number that Data Transfer will use for connections.
  # Target cluster settings:
  target_mysql_version = "" # Set MySQL version. It must be the same or higher than the version in the source cluster.
  target_sql_mode      = "" # Set the MySQL SQL mode. It must be the same as in the source cluster.
  target_db_name       = "" # Set the target cluster database name.
  target_user          = "" # Set the target cluster username.
  target_password      = "" # Set the target cluster password.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for MySQL cluster"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for MySQL cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = local.source_port
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.target_mysql_version
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  mysql_config = {
    sql_mode = local.target_sql_mode
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = "yandex_vpc_subnet.subnet-a.id"
  }

  database {
    name = local.target_db_name
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

resource "yandex_datatransfer_endpoint" "mysql-source" {
  description = "Source endpoint for MySQL cluster"
  name        = "mysql-source"
  settings {
    mysql_source {
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

resource "yandex_datatransfer_endpoint" "managed-mysql-target" {
  description = "Target endpoint for the Managed Service for MySQL cluster"
  name        = "managed-mysql-target"
  settings {
    target {
      connection {
        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
      }
      database = local.target_db_name
      user     = local.target_user
      password {
        raw = local.target_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mysql-transfer" {
  description = "Transfer from MySQL cluster to the Managed Service for MySQL cluster"
  name        = "transfer-from-onpremise-mysql-to-managed-mysql"
  source_id   = yandex_datatransfer_endpoint.mysql-source.id
  target_id   = yandex_datatransfer_endpoint.managed-mysql-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
}
