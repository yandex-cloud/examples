# Infrastructure for Yandex Cloud Managed Service for SQL Server
#
# RU: https://cloud.yandex.ru/docs/managed-sqlserver/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-sqlserver/tutorials/data-migration
#
# Set the configuration of the Managed Service for SQL Server cluster:
locals {
  sql_server_version = "" # Set the SQL Server version. Мust be the same or higher than the version in the source cluster.
  db_name            = "" # Set a database name
  username           = "" # Set a user name
  password           = "" # Set a user password
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for SQL Server cluster"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for SQL Server cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to SQL Server from the Internet"
    protocol       = "TCP"
    port           = 1433
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_sqlserver_cluster" "sqlserver-cluster" {
  description        = "Managed Service for SQL Server cluster"
  name               = "sqlserver-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.sql_server_version
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  resources {
    resource_preset_id = "s2.small" # 4 vCPU, 16 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = local.db_name
  }

  user {
    name     = local.username
    password = local.password

    permission {
      database_name = local.db_name
      roles         = ["OWNER"]
    }
  }
}
