# Infrastructure for Yandex Cloud Managed Service for MySQL, YDB, and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mmy-to-yds
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mmy-to-yds

# Specify the following settings
locals {
  mysql_password = "" # Set a password for the MySQL admin user
  folder_id      = "" # Set your cloud folder ID, same as for provider

  # Specify these settings ONLY AFTER the clusters are created. Then run "terraform apply" command again
  # You should set up the target endpoint using the GUI to obtain its ID
  yds_endpoint_id  = "" # Set the target endpoint ID
  transfer_enabled = 0  # Value '0' disables creating of transfer before the target endpoint is created manually. After that, set to '1' to enable transfer
}

# Resources for the Managed Service for MySQL

resource "yandex_vpc_network" "mmy_network" {
  description = "Network for Managed Service for MySQL"
  name        = "mmy_network"
}

resource "yandex_vpc_subnet" "mmy_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for MySQL"
  name           = "mmy_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mmy_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mmy_security_group" {
  network_id  = yandex_vpc_network.mmy_network.id
  name        = "Managed MySQL security group"
  description = "Security group for Managed Service for MySQL"

  ingress {
    description    = "Allow incoming traffic from the port 6432"
    protocol       = "TCP"
    port           = 3306
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

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mmy_network.id
  version            = "8.0"
  security_group_ids = [yandex_vpc_security_group.mmy_security_group.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mmy_subnet-a.id
    assign_public_ip = true # Required for connection from Internet
  }
}

# MySQL database

resource "yandex_mdb_mysql_database" "source-db" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = "db1"
}

# MySQL user

resource "yandex_mdb_mysql_user" "source-user" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = "mmy-user"
  password   = local.mysql_password
  permission {
    database_name = yandex_mdb_mysql_database.source-db.name
    roles         = ["ALL"]
  }
  global_permissions = ["REPLICATION_CLIENT", "REPLICATION_SLAVE"]
}

resource "yandex_iam_service_account" "yds-sa" {
  description = "Service account for migration from the Managed Service for MySQL to the Yandex Data Streams"
  name        = "yds-sa"
}

# Assign the `yds.editor` role to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "yds_editor" {
  folder_id = local.folder_id
  role      = "yds.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.yds-sa.id}"
  ]
}

resource "yandex_ydb_database_serverless" "ydb-example" {
  name = "ydb-example"
}

# Endpoint and transfer configurations

resource "yandex_datatransfer_endpoint" "mmy-source" {
  description = "Source endpoint for MySQL cluster"
  name        = "managed-mysql-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
      }
      database = "db1"
      user     = "mmy-user"
      password {
        raw = local.mysql_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mmy-to-yds-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for MySQL to the Yandex Data Streams"
  name        = "mmy-to-yds-transfer"
  source_id   = yandex_datatransfer_endpoint.mmy-source.id
  target_id   = local.yds_endpoint_id
  type        = "INCREMENT_ONLY" # Replicate data
}
