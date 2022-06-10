# Infrastructure for Yandex Cloud Managed Service for Kafka and MirrorMaker connector
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
#
# Set the configuration:

# Network

locals {
  source_admin      = ""                                  # source cluster admin account name
  source_password   = ""                                  # source cluster admin account password
  target_admin      = ""                                  # target cluster admin account name
  target_password   = ""                                  # target cluster admin account password
  topics            = "data.*"                            # Specify topics that must be to migrated
  source_alias      = "source"                            # Specify prefix for the source cluster
  target_alias      = "target"                            # Specify prefix for the target cluster
  bootstrap_servers = "somebroker1:9091,somebroker2:9091" # Specify bootstrap servers to connect to cluster
}

variable "kafka_version" {
  default = "2.8"
}

resource "yandex_vpc_network" "network" {
  description = "Network for Managed Service for Kafka and VM"
  name        = "network"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Subnet in ru-central1-b availability zone
resource "yandex_vpc_subnet" "subnet-b" {
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

# Subnet in ru-central1-c availability zone
resource "yandex_vpc_subnet" "subnet-c" {
  name           = "subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}

# Security group for Managed Service for Kafka
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  # Allow connections to Kafka cluster from the Internet
  ingress {
    description    = "Allow connections to Kafka cluster from the Internet"
    protocol       = "TCP"
    from_port      = 9091
    to_port        = 9092
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

# Yandex Managed Service for Apache Kafka® cluster
resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    brokers_count    = 1
    version          = var.kafka_version
    zones            = ["ru-central1-a"]
    unmanaged_topics = true # Topic management via the Admin API
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-hdd"
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      }
      kafka_config {
        auto_create_topics_enable = true
      }
    }
  }

  user {
    name     = local.target_admin
    password = local.target_password
    permission {
      topic_name = "*"
      role       = "ACCESS_ROLE_ADMIN"
    }
  }
}

resource "yandex_mdb_kafka_connector" "connector" {
  description = "MirrorMaker connector"
  cluster_id  = yandex_mdb_kafka_cluster.kafka-cluster.id
  name        = "replication"
  tasks_max   = 3
  properties = {
  #  refresh.topics.enabled = "true"
  }
  connector_config_mirrormaker {
    topics             = local.topics
    replication_factor = 1
    source_cluster {
      alias = local.source_alias
      external_cluster {
        bootstrap_servers = local.bootstrap_servers
        sasl_username     = local.source_admin
        sasl_password     = local.source_password
        sasl_mechanism    = "SCRAM-SHA-512" # Specify encryption algorythm for username and password
        security_protocol = "SASL_SSL"      # Specify connection protocol for the MirrorMaker connector
      }
    }
    target_cluster {
      alias = local.target_alias
      this_cluster {}
    }
  }
}