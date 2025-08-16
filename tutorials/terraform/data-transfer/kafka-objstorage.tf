# Infrastructure for Yandex Cloud Managed Service for Apache Kafka® and Yandex Object Storage
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/managed-kafka-to-obj-storage
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/managed-kafka-to-obj-storage

# Specify the following settings
locals {
  kf_version  = "" # Set a desired version of Apache Kafka®. For available versions, see the documentation main page : https://cloud.yandex.com/en/docs/managed-kafka/
  kf_password = "" # Set a password for the Apache Kafka® user
  folder_id   = "" # Set your cloud folder ID, same as for provider
  bucket      = "" # Set a unique bucket name

  # Specify these settings ONLY AFTER the cluster and the bucket are created. Then run "terraform apply" command again
  # You should set up endpoints using the GUI to obtain their IDs
  kf_source_endpoint_id = "" # Set the source endpoint ID
  os_target_endpoint_id = "" # Set the target endpoint ID
  transfer_enabled      = 0  # Set to 1 to enable transfer
}

resource "yandex_vpc_network" "mkf_network" {
  description = "Network for Managed Service for Apache Kafka®"
  name        = "mkf_network"
}

resource "yandex_vpc_subnet" "mkf_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for Apache Kafka®"
  name           = "mkf_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mkf_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mkf_security_group" {
  description = "Security group for Managed Service for Apache Kafka®"
  network_id  = yandex_vpc_network.mkf_network.id
  name        = "Managed Apache Kafka® security group"

  ingress {
    description    = "Allow incoming traffic from the port 9091"
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_kafka_cluster" "mkf-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
  environment        = "PRODUCTION"
  name               = "mkf-cluster"
  network_id         = yandex_vpc_network.mkf_network.id
  security_group_ids = [yandex_vpc_security_group.mkf_security_group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = local.kf_version
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro"
      }
    }

    zones = [
      "ru-central1-a"
    ]
  }

  user {
    name     = "mkf-user"
    password = local.kf_password
    permission {
      topic_name = "sensors"
      role       = "ACCESS_ROLE_CONSUMER"
    }
    permission {
      topic_name = "sensors"
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }
}

# Managed Service for Apache Kafka® topic
resource "yandex_mdb_kafka_topic" "sensors" {
  cluster_id         = yandex_mdb_kafka_cluster.mkf-cluster.id
  name               = "sensors"
  partitions         = 1
  replication_factor = 1
}

resource "yandex_iam_service_account" "storage-sa" {
  description = "A service account to manage buckets"
  folder_id   = local.folder_id
  name        = "storage-sa"
}

# Grant permissions to the service account
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.storage-sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  description        = "Static access key for Object Storage"
  service_account_id = yandex_iam_service_account.storage-sa.id
}

# Use keys to create a bucket
resource "yandex_storage_bucket" "obj-storage-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.bucket
}

resource "yandex_datatransfer_transfer" "mkf-os-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for Apache Kafka® to the Yandex Object Storage bucket"
  name        = "mkf-os-transfer"
  source_id   = local.kf_source_endpoint_id
  target_id   = local.os_target_endpoint_id
  type        = "INCREMENT_ONLY" # Data replication from the source Managed Service for Apache Kafka® topic to the target Yandex Object Storage bucket
}
