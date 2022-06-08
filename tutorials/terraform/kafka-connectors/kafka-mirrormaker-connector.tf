# Infrastructure for Yandex Cloud Managed Service for Kafka and MirrorMaker connector
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
#
# Set the configuration:

# Network
resource "yandex_vpc_network" "network" {
  name        = "network"
  description = "Network for Managed Service for Kafka and VM."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for Managed Service for Kafka
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  # Allow connections to Kafka cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow connections to Kafka cluster from the Internet"
    from_port      = 9091
    to_port        = 9092
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

# Yandex Managed Service for Apache Kafka® cluster
resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    brokers_count    = 1
    version          = "2.8"
    zones            = ["ru-central1-a"]
    unmanaged_topics = true # Topic management via the Admin API
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-hdd"
        resource_preset_id = "s2.micro"
      }
      kafka_config {
        auto_create_topics_enable = true
      }
    }
  }

  user {
    name     = "admin_source"   # admin account name
    password = "local.password" # admin account password
    permission {
      topic_name = "*"
      role       = "ACCESS_ROLE_ADMIN"
    }
  }
}

# MirrorMaker connector

resource "yandex_mdb_kafka_connector" "connector" {
  cluster_id = yandex_mdb_kafka_cluster.kafka-cluster.id
  name       = "replication"
  tasks_max  = 3
  properties = {
    refresh.topics.enabled = "true"
  }
  connector_config_mirrormaker {
    topics             = "data.*" # Specify topics that must be to migrated
    replication_factor = 1
    source_cluster {
      alias = "source" # Specify prefix for the source cluster
      external_cluster {
        bootstrap_servers = "somebroker1:9091,somebroker2:9091" # Specify bootstrap servers to connect to cluster
        sasl_username     = "admin_source"                      # admin account name
        sasl_password     = ""                                  # admin account password
        sasl_mechanism    = "SCRAM-SHA-512"                     # Specify encryption algorythm for username and password
        security_protocol = "SASL_SSL"                          # Specify connection protocol for the MirrorMaker connector
      }
    }
    target_cluster {
      alias = "target"
      this_cluster {}
    }
  }
}