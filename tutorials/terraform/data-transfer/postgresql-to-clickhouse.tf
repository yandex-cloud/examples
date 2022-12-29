# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster, Yandex Cloud Managed Service for PostgreSQL, and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/rdbms-to-clickhouse
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/rdbms-to-clickhouse

# Specify the following settings
locals {
  ch_password = "" # Set a password for the ClickHouse admin user
  pg_password = "" # Set a password for the PostgreSQL admin user

  transfer_enabled = 0 # Set to 1 ONLY AFTER a table in the source cluster is created. Then run the "terraform apply" command again to enable the transfer
}

resource "yandex_vpc_network" "mch_network" {
  description = "Network for Managed Service for ClickHouse"
  name        = "mch_network"
}

resource "yandex_vpc_network" "mpg_network" {
  description = "Network for Managed Service for PostgreSQL"
  name        = "mpg_network"
}

resource "yandex_vpc_subnet" "mch_subnet-a" {
  description    = "Subnet in ru-central1-a availability zone for ClickHouse"
  name           = "mch_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mch_network.id
  v4_cidr_blocks = ["10.126.0.0/18"]
}

resource "yandex_vpc_subnet" "mch_subnet-b" {
  description    = "Subnet in ru-central1-b availability zone for ClickHouse"
  name           = "mch_subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.mch_network.id
  v4_cidr_blocks = ["10.127.0.0/18"]
}

resource "yandex_vpc_subnet" "mch_subnet-c" {
  description    = "Subnet in ru-central1-c availability zone for ClickHouse"
  name           = "mch_subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.mch_network.id
  v4_cidr_blocks = ["10.128.0.0/18"]
}

resource "yandex_vpc_subnet" "mpg_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for PostgreSQL"
  name           = "mpg_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mpg_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mch_security_group" {
  network_id  = yandex_vpc_network.mch_network.id
  name        = "Managed ClickHouse security group"
  description = "Security group for Managed Service for ClickHouse"

  ingress {
    description    = "Allow incoming traffic from the port 8443"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming traffic from the port 9440"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to members of the same security group"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mpg_security_group" {
  network_id  = yandex_vpc_network.mpg_network.id
  name        = "Managed PostgreSQL security group"
  description = "Security group for Managed Service for PostgreSQL"

  ingress {
    description    = "Allow incoming traffic from the port 6432"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to members of the same security group"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_clickhouse_cluster" "mch-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "mch-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mch_network.id
  security_group_ids = [yandex_vpc_security_group.mch_security_group.id]

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
    subnet_id        = yandex_vpc_subnet.mch_subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.mch_subnet-b.id
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
    subnet_id = yandex_vpc_subnet.mch_subnet-a.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.mch_subnet-b.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-c"
    subnet_id = yandex_vpc_subnet.mch_subnet-c.id
  }

  database {
    name = "db1"
  }

  user {
    name     = "ch-user"
    password = local.ch_password
    permission {
      database_name = "db1"
    }
  }
}

# Resources for PostgreSQL cluster

resource "yandex_mdb_postgresql_user" "pg-user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = "pg-user"
  password   = local.pg_password
  grants     = ["mdb_replication"]
}

resource "yandex_mdb_postgresql_database" "mpg-db" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = "db1"
  owner      = yandex_mdb_postgresql_user.pg-user.name
  depends_on = [
    yandex_mdb_postgresql_user.pg-user
  ]
}

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed PostgreSQL cluster"
  name               = "mpg-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mpg_network.id
  security_group_ids = [yandex_vpc_security_group.mpg_security_group.id]

  config {
    version = 14
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = "20"
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mpg_subnet-a.id
    assign_public_ip = true
  }
}

# Endpoint and transfer configurations

resource "yandex_datatransfer_endpoint" "mpg-source" {
  description = "Source endpoint for PostgreSQL cluster"
  name        = "mpg-source"
  settings {
    postgres_source {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = "db1"
      user     = "pg-user"
      password {
        raw = local.pg_password
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
          mdb_cluster_id = yandex_mdb_clickhouse_cluster.mch-cluster.id
          database       = "db1"
          user           = "ch-user"
          password {
            raw = local.ch_password
          }
        }
      }
      cleanup_policy = "CLICKHOUSE_CLEANUP_POLICY_DROP"
    }
  }
}

resource "yandex_datatransfer_transfer" "mpg-to-mch-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for PostgreSQL to the Managed Service for ClickHouse"
  name        = "transfer-from-mpg-to-mch"
  source_id   = yandex_datatransfer_endpoint.mpg-source.id
  target_id   = yandex_datatransfer_endpoint.mch-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication
}
