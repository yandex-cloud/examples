# Infrastructure for Yandex Cloud Managed Service for SQL Server.
#
# RU: https://cloud.yandex.ru/docs/managed-sqlserver/tutorials/migration-with-bucket
# EN: https://cloud.yandex.com/en/docs/managed-sqlserver/tutorials/migration-with-bucket

# Set the configuration of the Managed Service for SQL Server cluster:
locals {
  folder_id          = "" # Your Folder ID.
  sql_server_version = "" # Set an SQL Server version. It must be the same or higher than the version in the source cluster.
  db_name            = "" # Set a database name.
  username           = "" # Set a user name.
  password           = "" # Set a user password.
  storage_sa_id      = "" # Set the service account ID for creating a bucket in Object Storage.
  cluster_sa         = "" # Set a service account name of the cluster. It must be unique in the folder.
  bucket_name        = "" # Set an Object Storage bucket name. It must be unique throughout Object Storage.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for SQL Server cluster"
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
  description = "Security group for the Managed Service for SQL Server cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to SQL Server from the Internet"
    protocol       = "TCP"
    port           = 1433
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_sqlserver_cluster" "sqlserver-cluster" {
  description        = "Managed Service for SQL Server cluster"
  name               = "sqlserver-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.sql_server_version
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  resources {
    resource_preset_id = "s2.small" # 4 vCPU, 16 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-a.id
  }

  database {
    name = local.db_name
  }

  user {
    name     = local.username
    password = local.password

    permission {
      database_name = local.db_name
      roles         = ["OWNER"]
    }
  }
}

resource "yandex_iam_service_account" "cluster-sa" {
  description = "Service account to manage the SQL Server cluster"
  name        = local.cluster_sa
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  description        = "Object Storage bucket static key"
  service_account_id = local.storage_sa_id
}

# Object Storage bucket
resource "yandex_storage_bucket" "storage-bucket" {
  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key

  grant {
    id          = yandex_iam_service_account.cluster-sa.id
    type        = "CanonicalUser"
    permissions = ["READ", "WRITE"]
  }
}
