# Infrastructure for the Yandex Cloud Data Streams, Object Storage, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mmy-objs-migration
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mmy-objs-migration
#
# Set the source Managed Service for MySQL cluster and target Object Storage bucket settings.
locals {
  folder_id = "" # Your Folder ID.
  sa_name   = "" # Set a service account name. It must be unique in the folder.

  # Source MySQL database settings:
  source_mysql_version = "" # Set the MySQL version.
  source_db_name       = "" # Set the source MySQL database name.
  source_user          = "" # Set the source cluster username.
  source_password      = "" # Set the source cluster password.

  # Target bucket settings:
  bucket_name        = "" # Set an Object Storage bucket name. It must be unique throughout Object Storage.
  target_endpoint_id = "" # Set the target endpoint id.

  # Transfer settings:
  transfer_enable = 0 # Set to 1 to enable transfer.
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
    port           = 3306 # MySQL port number
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

  mysql_config = {
    binlog_row_image = "FULL"
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

resource "yandex_iam_service_account" "sa-yds-obj" {
  description = "Service account for migration from the Data Streams to Object Storage"
  name        = local.sa_name
}

# Assign role `editor` to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

# Assign role `storage.editor` to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "storage_editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

# Assign role `storage.uploader` to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "storage_uploader" {
  folder_id = local.folder_id
  role      = "storage.uploader"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

resource "yandex_iam_service_account_static_access_key" "bucket-key" {
  description        = "Object Storage bucket static key"
  service_account_id = yandex_iam_service_account.sa-yds-obj.id
}

# Object Storage bucket
resource "yandex_storage_bucket" "storage-bucket" {
  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.bucket-key.secret_key
}

resource "yandex_datatransfer_endpoint" "managed-mysql-source" {
  description = "Source endpoint for MySQL cluster"
  name        = "managed-mysql-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
      }
      database = local.source_db_name
      user     = local.source_user
      password {
        raw = local.source_password
      }
      #include_tables_regex = [""]
      #exclude_tables_regex = [""]
    }
  }
}

resource "yandex_datatransfer_transfer" "mmy-objs-transfer" {
  count       = local.transfer_enable
  description = "Transfer from the Managed Service for MySQL to the Object Storage"
  name        = "transfer-from-mmy-to-objstorage"
  source_id   = yandex_datatransfer_endpoint.managed-mysql-source.id
  target_id   = local.target_endpoint_id
  type        = "SNAPSHOT_ONLY" # Copying data from the source Managed Service for MySQL database.
}
