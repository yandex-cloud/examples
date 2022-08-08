# Infrastructure for the Yandex Cloud Managed Service for Apache Kafka® and ClickHouse clusters
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
#
# Set the configuration of the Managed Service for Apache Kafka® and ClickHouse clusters

# Set the following settings:

locals {
  producer_name     = "" # Set name of the producer.
  producer_password = "" # Set the password of the producer.
  topic_name        = "" # Set the Kafka topic name. Each Managed Service for Apache Kafka® cluster must have its unique topic name.
  consumer_name     = "" # Set name of the consumer.
  consumer_password = "" # Set the password of the consumer.
  db_user_name      = "" # Set database username.
  db_user_password  = "" # Set database user password.
}


resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka® and ClickHouse clusters"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}


resource "yandex_vpc_default_security_group" "security-group" {
  description = "Security group for the Managed Service for Apache Kafka® and ClickHouse clusters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® cluster from the Internet"
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "# Allow connections to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
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
    name     = local.producer_name
    password = local.producer_password
    permission {
      topic_name = local.topic_name
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }

  user {
    name     = local.consumer_name
    password = local.consumer_password
    permission {
      topic_name = local.topic_name
      role       = "ACCESS_ROLE_CONSUMER"
    }
  }
}

resource "yandex_mdb_kafka_topic" "events" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = local.topic_name
  partitions         = 4
  replication_factor = 1
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
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
    name     = local.db_user_name
    password = local.db_user_password
    permission {
      database_name = "db1"
    }
  }
}
