# Infrastructure for the Yandex Cloud Managed Service for Apache Kafka, Managed Service for ClickHouse and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mkf-to-mch
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mkf-to-mch
#
# Set source cluster and target cluster settings.
locals {
  # Source cluster settings:
  source_user_producer     = "" # Set the name of the producer.
  source_password_producer = "" # Set the password of the producer.
  source_user_consumer     = "" # Set the name of the consumer.
  source_password_consumer = "" # Set the password of the consumer.
  source_topic_name        = "" # Set the topic name.
  #source_endpoint_id       = "" # Set the source endpoint id.

  # Target database settings:
  target_db_name  = "" # Set the target cluster database name.
  target_user     = "" # Set the username for ClickHouse cluster.
  target_password = "" # Set the user password for ClickHouse cluster.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka and Managed Service for ClickHouse clusters"
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
  description = "Security group for the Managed Service for Apache Kafka and Managed Service for ClickHouse clusters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka cluster from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 9091
    to_port        = 9092
  }

  ingress {
    description    = "Allow connections with clickhouse-client to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTP connections to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 8443
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

resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  description        = "Managed Service for Kafka cluster"
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  config {
    brokers_count    = 1
    version          = "3.0"
    zones            = ["ru-central1-a"]
    assign_public_ip = true
    kafka {
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 10 # GB
      }
    }
  }

  user {
    name     = local.source_user_producer
    password = local.source_password_producer
    permission {
      topic_name = local.source_topic_name
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }

  user {
    name     = local.source_user_consumer
    password = local.source_password_consumer
    permission {
      topic_name = local.source_topic_name
      role       = "ACCESS_ROLE_CONSUMER"
    }
  }
}

resource "yandex_mdb_kafka_topic" "source-topic" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = local.source_topic_name
  partitions         = 2
  replication_factor = 1
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = local.target_db_name
  }

  user {
    name     = local.target_user
    password = local.target_password
    permission {
      database_name = local.target_db_name
    }
  }
}

#resource "yandex_datatransfer_endpoint" "mch-target" {
#  description = "Target endpoint for ClickHouse cluster"
#  name        = "mch-target"
#  settings {
#    clickhouse_target {
#      connection {
#        connection_options {
#          mdb_cluster_id = yandex_mdb_clickhouse_cluster.clickhouse-cluster.id
#          database       = local.target_db_name
#          user           = local.target_user
#          password {
#            raw = local.target_password
#          }
#        }
#      }
#      cleanup_policy = "CLICKHOUSE_CLEANUP_POLICY_DROP"
#    }
#  }
#}

#resource "yandex_datatransfer_transfer" "mysql-transfer" {
#  description = "Transfer from the Managed Service for Kafka to the Managed Service for ClickHouse"
#  name        = "transfer-from-mkf-to-mch"
#  source_id   = local.source_endpoint_id
#  target_id   = yandex_datatransfer_endpoint.mch-target.id
#  type        = "INCREMENT_ONLY" # Replication data from the source Data Stream.
#}
