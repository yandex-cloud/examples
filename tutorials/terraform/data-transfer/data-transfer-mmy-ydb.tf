# Infrastructure for the Yandex Cloud Managed Service for MySQL cluster, Managed Service for YDB and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/managed-mysql-to-yds
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/managed-mysql-to-yds
#
# Set source cluster and target database settings.
locals {
  # Source cluster settings:
  source_mysql_version = ""   # Set MySQL version.
  source_db_name       = ""   # Set the source cluster database name.
  source_user          = ""   # Set the source cluster username.
  source_password      = ""   # Set the source cluster password.
  source_port          = 3306 # Set the source cluster port number that Data Transfer will use for connections.
  # Target database settings:
  target_db_name = "" # Set the target database name.
  # target_endpoint_id = "" # Set the target endpoint id.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for MySQL cluster and Managed Service for YDB"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for MySQL cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = local.source_port
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

resource "yandex_ydb_database_serverless" "ydb" {
  name = local.target_db_name
}

#resource "yandex_datatransfer_endpoint" "managed-mysql-source" {
#  description = "Source endpoint for MySQL cluster"
#  name        = "managed-mysql-source"
#  settings {
#    mysql_source {
#      connection {
#        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
#      }
#      database = local.source_db_name
#      user     = local.source_user
#      password {
#        raw = local.source_password
#      }
#    }
#  }
#}

#resource "yandex_datatransfer_transfer" "mysql-transfer" {
#  description = "Transfer from the Managed Service for MySQL cluster to the Managed Service for YDB"
#  name        = "transfer-from-managed-mysql-to-ydb"
#  source_id   = yandex_datatransfer_endpoint.managed-mysql-source.id
#  target_id   = local.target_endpoint_id
#  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
#}
