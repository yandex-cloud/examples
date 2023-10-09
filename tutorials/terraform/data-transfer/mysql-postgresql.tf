# Infrastructure for the Yandex Cloud Managed Service for MySQL, Managed Service for PostgreSQL, and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mmy-to-mpg
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mmy-to-mpg
#
# Specify the following settings:

locals {
  # Settings for Managed Service for PostgreSQL cluster:
  pg_version       = "" # Desired version of PostgreSQL. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-postgresql/.
  pg_user_password = "" # User password

  # Settings for Managed Service for MySQL cluster:
  mysql_version       = "" # Desired version of MySQL. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-mysql/.
  mysql_user_password = "" # User password

  # Change this setting ONLY AFTER the clusters are created. Then run "terraform apply" command again.
  transfer_enabled = 0 # Set to 1 to enable Transfer

  # The following settings are predefined. Change them only if necessary.
  network_name          = "mmy-mpg-network"    # Name of the network
  subnet_name           = "subnet-a"           # Name of the subnet
  zone_a_v4_cidr_blocks = "10.1.0.0/16"        # CIDR block for the subnet in the ru-central1-a availability zone
  security_group_name   = "security-group"     # Name of the security group
  pg_cluster_name       = "postgresql-cluster" # Name of the PostgreSQL cluster
  pg_db_name            = "mpg-db"             # Name of the PostgreSQL cluster database
  pg_username           = "mpg-user"           # Name of the PostgreSQL username
  mysql_cluster_name    = "mysql-cluster"      # Name of the MySQL cluster
  mysql_db_name         = "mmy-db"             # Name of the MySQL cluster database
  mysql_username        = "mmy-user"           # Name of the MySQL cluster username
  source_endpoint_name  = "mmy_source"         # Name of the source endpoint for MySQL cluster
  target_endpoint_name  = "mpg_target"         # Name of the target endpoint for PostgreSQL cluster
  transfer_name         = "mmy-mpg-transfer"   # Name of the transfer from the Managed Service for MySQL to the Managed Service for PostgreSQL
}

# Network resources

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for PostgreSQL and MySQL clusters"
  name        = local.network_name
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for PostgreSQL and Managed Service for MySQL clusters"
  name        = local.security_group_name
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "The rule allows connections to the Managed Service for PostgreSQL cluster from the Internet"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "The rule allows connections to the Managed Service for MySQL cluster from the Internet"
    protocol       = "TCP"
    port           = 3306
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

# PostgreSQL cluster

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = local.pg_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  config {
    version = local.pg_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = "20" # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}

# User of the Managed Service for PostgreSQL cluster
resource "yandex_mdb_postgresql_user" "pg-user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.pg_username
  password   = local.pg_user_password
}

# Database of the Managed Service for PostgreSQL cluster
resource "yandex_mdb_postgresql_database" "mpg-db" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.pg_db_name
  owner      = yandex_mdb_postgresql_user.pg-user.name
  depends_on = [
    yandex_mdb_postgresql_user.pg-user
  ]
}

# MySQL cluster

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = local.mysql_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.mysql_version
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

resource "yandex_mdb_mysql_database" "mmy-db" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.mysql_db_name
}

resource "yandex_mdb_mysql_user" "mmy-user" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.mysql_username
  password   = local.mysql_user_password
  permission {
    database_name = yandex_mdb_mysql_database.mmy-db.name
    roles         = ["ALL"]
  }

  global_permissions = ["REPLICATION_CLIENT", "REPLICATION_SLAVE"]
}

# Transfer

resource "yandex_datatransfer_endpoint" "mmy-source" {
  description = "Source endpoint for MySQL cluster"
  name        = "mmy-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
      }
      database = local.mysql_db_name
      user     = local.mysql_username
      password {
        raw = local.mysql_user_password
      }
    }
  }
}

resource "yandex_datatransfer_endpoint" "mpg-target" {
  description = "Target endpoint for PostgreSQL cluster"
  name        = "mpg-target"
  settings {
    postgres_target {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = yandex_mdb_postgresql_database.mpg-db.name
      user     = yandex_mdb_postgresql_user.pg-user.name
      password {
        raw = local.pg_user_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mysql-pg-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for MySQL to the Managed Service for PostgreSQL"
  name        = "transfer-from-mmy-to-mpg"
  source_id   = yandex_datatransfer_endpoint.mmy-source.id
  target_id   = yandex_datatransfer_endpoint.mpg-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
}
