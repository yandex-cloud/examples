# Infrastructure for the Yandex Cloud Managed Service for PostgreSQL cluster.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/operations/logical-replica-from-rds
# EN: https://cloud.yandex.com/en/docs/managed-postgresql/operations/logical-replica-from-rds
#
# Set the configuration of the Managed Service for PostgreSQL cluster:
locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  pg_version            = "14"          # Set the PostgreSQL version. It must be the same or higher than the version in the Amazon RDS. See the complete list of the supported versions in https://cloud.yandex.com/en/docs/managed-postgresql/.
  db_name               = ""            # Set a database name. It must be the same as in the Amazon RDS.
  username              = ""            # Set a database owner name.
  password              = ""            # Set a database owner password.
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
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "cluster-security-group" {
  description = "Security group for the Managed Service for PostgreSQL cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_postgresql_cluster" "postgresql-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = "postgresql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.cluster-security-group.id]

  config {
    version = local.pg_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = "10" # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}

# User of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_user" "user" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-cluster.id
  name       = local.username
  password   = local.password
}

# Database of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_database" "database" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-cluster.id
  name       = local.db_name
  owner      = yandex_mdb_postgresql_user.user.name

  # Uncomment, multiply this block, and add the same PostgreSQL extensions as in Amazon RDS.
  #extension {
  #  name = "" # Set a name of the PostgreSQL extension.
  #}
}
