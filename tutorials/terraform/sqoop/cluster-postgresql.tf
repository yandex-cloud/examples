# Infrastructure for Yandex Cloud Managed Service for PostgreSQL cluster.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/tutorials/sqoop
#
# Set the configuration of the Managed Service for PostgreSQL cluster:
locals {
  network_id          = "" # Network ID for Managed Service for PostgreSQL cluster, Data Proc cluster and VM.
  subnet_id           = "" # Subnet ID (enable NAT for this subnet).
  pg_cluster_version  = "" # Set the PostgreSQL version.
  pg_cluster_password = "" # Set a user password.
}

resource "yandex_vpc_security_group" "cluster-security-group" {
  description = "Security group for the Managed Service for PostgreSQL cluster"
  network_id  = local.network_id

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
  network_id         = local.network_id
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
    name  = "db1"   # Database name
    owner = "user1" # Base owner name
  }

  user {
    name     = "user1" # Base owner name
    password = local.pg_cluster_password

    permission {
      database_name = "db1" # Database name
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = local.subnet_id
  }
}
