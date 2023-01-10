# Infrastructure for the Yandex Cloud Managed Service for MySQL, Managed Service for ClickHouse, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mysql-to-clickhouse
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mysql-to-clickhouse
#
# Set source cluster and target cluster settings.
locals {
  # Source cluster settings:
  source_mysql_version = "8.0" # Set MySQL version.
  source_db_name       = ""    # Set the source cluster database name.
  source_user          = ""    # Set the source cluster username.
  source_password      = ""    # Set the source cluster password.

  # Target database settings:
  target_user     = "" # Set the username for ClickHouse database.
  target_password = "" # Set the user password for ClickHouse database.

  # Transfer settings:
  transfer_enable = 0 # Set to 1 to enable Transfer.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for MySQL and Managed Service for ClickHouse clusters"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  description    = "Subnet in the ru-central1-b availability zone"
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-c" {
  description    = "Subnet in the ru-central1-c availability zone"
  name           = "subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for MySQL and Managed Service for ClickHouse clusters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for MySQL cluster from the Internet"
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow connections with a ClickHouse client to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTP connections to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "The rule allows all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.source_mysql_version
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from Internet
  }
}

resource "yandex_mdb_mysql_database" "source-db" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.source_db_name
}

resource "yandex_mdb_mysql_user" "source-user" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.source_user
  password   = local.source_password
  permission {
    database_name = yandex_mdb_mysql_database.source-db.name
    roles         = ["ALL"]
  }

  global_permissions = ["REPLICATION_CLIENT", "REPLICATION_SLAVE"]
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.subnet-b.id
    assign_public_ip = true # Required for connection from the Internet
  }

  zookeeper {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10
    }
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-a.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.subnet-b.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-c"
    subnet_id = yandex_vpc_subnet.subnet-c.id
  }

  database {
    name = local.source_db_name
  }

  user {
    name     = local.target_user
    password = local.target_password
    permission {
      database_name = local.source_db_name
    }
  }
}

resource "yandex_datatransfer_endpoint" "mmy-source" {
  description = "Source endpoint for MySQL cluster"
  name        = "mmy-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
      }
      database = local.source_db_name
      user     = local.source_user
      password {
        raw = local.source_password
      }
    }
  }
}

resource "yandex_datatransfer_endpoint" "mch-target" {
  description = "Target endpoint for ClickHouse cluster"
  name        = "mch-target"
  settings {
    clickhouse_target {
      connection {
        connection_options {
          mdb_cluster_id = yandex_mdb_clickhouse_cluster.clickhouse-cluster.id
          database       = local.source_db_name
          user           = local.target_user
          password {
            raw = local.target_password
          }
        }
      }
      cleanup_policy = "CLICKHOUSE_CLEANUP_POLICY_DROP"
    }
  }
}

resource "yandex_datatransfer_transfer" "mysql-transfer" {
  count       = local.transfer_enable
  description = "Transfer from the Managed Service for MySQL to the Managed Service for ClickHouse"
  name        = "transfer-from-mmy-to-mch"
  source_id   = yandex_datatransfer_endpoint.mmy-source.id
  target_id   = yandex_datatransfer_endpoint.mch-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
}
