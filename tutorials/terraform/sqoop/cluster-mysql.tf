# Infrastructure for Yandex Cloud Managed Service for MySQL cluster.
#
# RU: https://cloud.yandex.ru/docs/managed-mysql/tutorials/sqoop
#
# Set the configuration of the Managed Service for MySQL cluster:
locals {
  network_id          = "" # Network ID for Managed Service for MySQL cluster, Data Proc cluster and VM.
  subnet_id           = "" # Subnet ID (enable NAT for this subnet).
  my_cluster_version  = "" # Set the MySQL version.
  my_cluster_password = "" # Set a user password.
}

resource "yandex_vpc_security_group" "cluster-security-group" {
  description = "Security group for the Managed Service for MySQL cluster"
  network_id  = local.network_id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = local.network_id
  version            = local.my_cluster_version
  security_group_ids = [yandex_vpc_security_group.cluster-security-group.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = "10" # GB
  }

  database {
    name = "db1" # Database name
  }

  user {
    name     = "user1" # Base owner name
    password = local.my_cluster_password
    permission {
      database_name = "db1" # Database name
      roles         = ["ALL"]
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = local.subnet_id
  }
}
