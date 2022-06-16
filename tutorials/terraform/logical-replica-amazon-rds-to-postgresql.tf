# Infrastructure for the Yandex Cloud Managed Service for PostgreSQL cluster.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/operations/logical-replica-from-rds
# EN: https://cloud.yandex.com/en/docs/managed-postgresql/operations/logical-replica-from-rds
#
# Set the configuration of the Managed Service for PostgreSQL cluster:
locals {
  pg_cluster_version  = "14" # Set the PostgreSQL version. It must be the same or higher than the version in the Amazon RDS. See the complete list of supported versions in https://cloud.yandex.com/en/docs/managed-postgresql/.
  pg_cluster_db_name  = ""   # Set a database name. It must be the same as in the Amazon RDS.
  pg_cluster_username = ""   # Set a database owner name.
  pg_cluster_password = ""   # Set a database owner password.
}
# Add the same PostgreSQL extensions as in Amazon RDS. Look line 61.

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
    version = local.pg_cluster_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = "10" # GB
    }
  }

  database {
    name  = local.pg_cluster_db_name
    owner = local.pg_cluster_username

    # Uncomment, multiply this block and аdd the same PostgreSQL extensions as in Amazon RDS.
    #extension {
    #  name    = "" # Set a name of the PostgreSQL extensions.
    #  version = "" # Set a version of the PostgreSQL extensions.
    #}
  }

  user {
    name     = local.pg_cluster_username
    password = local.pg_cluster_password

    permission {
      database_name = local.pg_cluster_db_name
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}
