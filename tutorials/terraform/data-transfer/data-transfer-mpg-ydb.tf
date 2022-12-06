# Infrastructure for the Yandex Cloud YDB, Managed Service for PostgreSQL, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/data-transfer-mpg-ydb
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/data-transfer-mpg-ydb
#
# Set source cluster and target database settings.
locals {
  # Source Managed Service for PostgreSQL cluster settings:
  source_pg_version    = ""   # Set the PostgreSQL version.
  source_db_name       = ""   # Set a PostgreSQL database name.
  source_user_name     = ""   # Set a username in the Managed Service for PostgreSQL cluster.
  source_user_password = ""   # Set a password for the user in the Managed Service for PostgreSQL cluster.

  # Target YDB settings:
  target_db_name = "" # Set a YDB database name.

# Specify these settings ONLY AFTER the YDB database is created. Then run "terraform apply" command again.  
  # You should set up the target endpoint using the management console to obtain its ID.
  target_endpoint_id = "" # Set the target endpoint id.

  # Transfer settings:
  transfer_enabled = 0 # Value '0' disables creating of transfer before the target endpoint is created manually. After that, set to '1' to enable transfer.
}

resource "yandex_vpc_network" "network" {
  name        = "network"
  description = "Network for the Managed Service for PostgreSQL cluster and Managed Service for YDB"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for the Managed Service for PostgreSQL cluster
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to the Managed Service for PostgreSQL cluster from the Internet"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for PostgreSQL cluster
resource "yandex_mdb_postgresql_cluster" "pgsql-cluster" {
  name               = "pgsql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    version = local.source_pg_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = 10 # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    name             = "host_name_a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true
  }
}

resource "yandex_mdb_postgresql_user" "user1" {
  cluster_id = yandex_mdb_postgresql_cluster.pgsql-cluster.id
  name       = local.source_user_name
  password   = local.source_user_password
  grants     = ["mdb_replication"]
}

resource "yandex_mdb_postgresql_database" "db1" {
  cluster_id = yandex_mdb_postgresql_cluster.pgsql-cluster.id
  name       = local.source_db_name
  owner      = yandex_mdb_postgresql_user.user1.name
}

resource "yandex_ydb_database_serverless" "ydb" {
  name = local.target_db_name
}

resource "yandex_datatransfer_endpoint" "pg_source" {
  count       = local.transfer_enabled
  name        = "mpg-source"
  description = "Endpoint for the Managed Service for PostgreSQL source cluster"
  settings {
    postgres_source {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.pgsql-cluster.id
      }
      database = local.source_db_name
      user     = local.source_user_name
      password {
        raw = local.source_user_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mpg-ydb-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for PostgreSQL cluster to the YDB database"
  name        = "transfer-from-mpg-to-ydb"
  source_id   = yandex_datatransfer_endpoint.pg_source.id
  target_id   = local.target_endpoint_id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy and replicate data from the source PostgreSQL database.
}
