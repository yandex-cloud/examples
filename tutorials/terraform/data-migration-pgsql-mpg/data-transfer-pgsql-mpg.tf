# Infrastructure for the Yandex Cloud Managed Service for PostgreSQL cluster and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-postgresql/tutorials/data-migration

# Specify the source and target clusters settings.
locals {
  # Source cluster settings:
  source_user    = ""   # Set the source cluster username.
  source_db_name = ""   # Set the source cluster database name. It is also used for target cluster database.
  source_pwd     = ""   # Set the source cluster password.
  source_host    = ""   # Set the source cluster master host IP address or FQDN.
  source_port    = 6432 # Set the source cluster port number that Data Transfer will use for connections.
  # Target cluster settings:
  target_pgsql_version = "" # Set PostgreSQL version. It must match the version of the source cluster.
  target_user          = "" # Set the target cluster username.
  target_password      = "" # Set the target cluster password.
}

# Source cluster PostgreSQL extensions to be enabled in the Managed Service for PostgreSQL cluster:
variable "pg-extensions" {
  description = "List of extensions for the Managed Service for PostgreSQL cluster"
  type        = set(string)
  default = [
    # Put the list of the source database PostgreSQL extensions.
    # Example:
    # "pg_qualstats",
    # "dblink"
  ]
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for PostgreSQL cluster"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group-mpg" {
  description = "Security group for the Managed Service for PostgreSQL cluster"
  network_id  = yandex_vpc_network.network.id
}

resource "yandex_vpc_security_group_rule" "rule-cluster" {
  security_group_binding = yandex_vpc_security_group.security-group-mpg.id
  direction              = "ingress"
  description            = "Allow connections to the cluster from the Internet"
  protocol               = "TCP"
  port                   = local.source_port
  v4_cidr_blocks         = ["0.0.0.0/0"]
}

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = "mpg-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  config {
    version = local.target_pgsql_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = 10 # GB
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-a.id
  }
}

# A PostgreSQL database of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_database" "mpg-db" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.source_db_name

  # Set the names of PostgreSQL extensions using a cycle.
  dynamic "extension" {
    for_each = var.pg-extensions
    content {
      name = extension.value
    }
  }
}

# A PostgreSQL user of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_user" "mpg-user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.target_user
  password   = local.target_password
  permission {
    database_name = local.source_db_name
  }
  grants = ["ALL"]
}

resource "yandex_datatransfer_endpoint" "pgsql-source" {
  description = "Source endpoint for PostgreSQL cluster"
  name        = "pgsql-source"
  settings {
    pgsql_source {
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

resource "yandex_datatransfer_endpoint" "mpg-target" {
  description = "Target endpoint for the Managed Service for PostgreSQL cluster"
  name        = "mpg-target"
  settings {
    target {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = local.source_db_name
      user     = local.target_user
      password {
        raw = local.target_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "pgsql-transfer" {
  description = "Transfer from PostgreSQL cluster to the Managed Service for PostgreSQL cluster"
  name        = "transfer-from-onpremise-pgsql-to-managed-pgsql"
  source_id   = yandex_datatransfer_endpoint.pgsql-source.id
  target_id   = yandex_datatransfer_endpoint.mpg-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
}
