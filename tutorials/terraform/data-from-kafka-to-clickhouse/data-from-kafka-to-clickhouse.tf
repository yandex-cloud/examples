# Infrastructure for Yandex Cloud Managed Service for Kafka and ClickHouse clusters
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
#
# Set the configuration of Managed Service for Kafka and ClickHouse clusters


# Network
resource "yandex_vpc_network" "network" {
  name        = "network"
  description = "Network for Managed Service for Kafka and ClickHouse clusters."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for Managed Service for Kafka and ClickHouse clusters
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  # Allow connections to Kafka cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow connections to Kafka cluster from the Internet"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connections to ClickHouse cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "# Allow connections to ClickHouse cluster from the Internet"
    port           = 9440
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

# Managed Service for Kafka cluster
resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = "2.8"
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
    name     = "" # Set name of the producer
    password = "" # Set password of the producer
    permission {
      topic_name = "" # Topic name from line 94
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }

  user {
    name     = "" # Set name of the consumer
    password = "" # Set password of the consumer
    permission {
      topic_name = "" # Topic name from line 94
      role       = "ACCESS_ROLE_CONSUMER"
    }
  }
}

resource "yandex_mdb_kafka_topic" "events" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = "" # Set topic name. Topic names should not be repeated.
  partitions         = 4
  replication_factor = 1
}

# Managed Service for ClickHouse cluster
resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
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
    name = "db1"
  }

  user {
    name     = "" # Set username for ClickHouse cluster
    password = "" # Set user password for ClickHouse cluster
    permission {
      database_name = "db1"
    }
  }
}
