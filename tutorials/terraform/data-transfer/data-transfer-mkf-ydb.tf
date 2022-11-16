# Infrastructure for the Yandex Cloud YDB, Managed Service for Apache Kafka and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/data-transfer-mkf-ydb
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/data-transfer-mkf-ydb
#
# Set source cluster and target database settings.
locals {
  # Source Managed Service for Apache Kafka cluster settings:
  source_kf_version    = "" # Set Managed Service for Apache Kafka cluster version.
  source_user_name     = "" # Set a username in the Managed Service for Apache Kafka cluster.
  source_user_password = "" # Set a password for the user in the Managed Service for Apache Kafka cluster.
  source_endpoint_id   = "" # Set the source endpoint id.

  # Target YDB settings:
  target_db_name     = "" # Set a YDB database name.
  target_endpoint_id = "" # Set the target endpoint id.

  # Transfer settings:
  transfer_enable = 0 # Set to 1 to enable Transfer.
}

resource "yandex_vpc_network" "network" {
  name        = "network"
  description = "Network for the Managed Service for Apache Kafka® and ClickHouse clusters"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for the Managed Service for Apache Kafka® and ClickHouse clusters
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to the Managed Service for Apache Kafka® cluster from the Internet"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for Apache Kafka® cluster
resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = local.source_kf_version
    zones            = ["ru-central1-a"]
    kafka {
      resources {
        resource_preset_id = "s2.micro"
        disk_type_id       = "network-hdd"
        disk_size          = 10 # GB
      }
    }
  }

  user {
    name     = local.source_user_name
    password = local.source_user_password
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

resource "yandex_mdb_kafka_topic" "sensors" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = "sensors"
  partitions         = 4
  replication_factor = 1
}

resource "yandex_ydb_database_serverless" "ydb" {
  name = local.target_db_name
}

resource "yandex_datatransfer_transfer" "mkf-ydb-transfer" {
  count       = local.transfer_enable
  description = "Transfer from the Managed Service for Apache Kafka to the YDB database"
  name        = "transfer-from-mkf-to-ydb"
  source_id   = local.source_endpoint_id
  target_id   = local.target_endpoint_id
  type        = "INCREMENT_ONLY" # Replication data from the source Data Stream.
}
