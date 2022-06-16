# Infrastructure for Yandex Cloud Managed Service for Apache Kafka® and MirrorMaker connector
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
#
# Set the configuration:

# Network

locals {
  source_user             = ""                          # Source cluster user account name.
  source_password          = ""                          # Source cluster user account password.
  source_alias             = "source"                    # Specify prefix for the source cluster.
  source_bootstrap_servers = "<FQDN1>:9091,<FQDN2>:9091" # Specify bootstrap servers to connect to cluster.
  target_user             = ""                          # Target cluster user account name.
  target_password          = ""                          # Target cluster user account password.
  target_alias             = "target"                    # Specify prefix for the target cluster.
  topics_prefix            = "data.*"                    # Specify topics that must be migrated.
  kafka_version = "2.8" # Specify version of Managed Service for Apache Kafka®
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka® cluster and VM"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  description    = "Subnet in ru-central1-b availability zone"
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-c" {
  description    = "Subnet in ru-central1-c availability zone"
  name           = "subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}

resource "yandex_vpc_default_security_group" "security-group" {
  description = "Security group for Managed Service for the Managed Service for Apache Kafka® cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® cluster from the Internet"
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

resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  description        = "Managed Service for the Managed Service for Apache Kafka® cluster"
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    brokers_count    = 1
    version          = local.kafka_version
    zones            = ["ru-central1-a"]
    unmanaged_topics = true # Topic management via the Admin API.
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-hdd"
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM.
      }
      kafka_config {
        auto_create_topics_enable = true
      }
    }
  }

  user {
    name     = local.target_user
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
  connector_config_mirrormaker {
    topics             = local.topics_prefix
    replication_factor = 1
    source_cluster {
      alias = local.source_alias
      external_cluster {
        bootstrap_servers = local.source_bootstrap_servers
        sasl_username     = local.source_user
        sasl_password     = local.source_password
        sasl_mechanism    = "SCRAM-SHA-512" # Specify encryption algorythm for username and password.
        security_protocol = "SASL_SSL"      # Specify connection protocol for the MirrorMaker connector.
      }
    }
    target_cluster {
      alias = local.target_alias
      this_cluster {}
    }
  }
}
