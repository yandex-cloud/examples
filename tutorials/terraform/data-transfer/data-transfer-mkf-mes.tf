# Infrastructure for the Yandex Cloud Managed Service for Apache Kafka®, Managed Service for Elasticsearch and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/data-transfer-mkf-mes
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/data-transfer-mkf-mes
#
# Specify the following settings:
locals {
  # Source Managed Service for Apache Kafka® cluster settings:
  source_kf_version    = "" # Set a desired version of Apache Kafka®. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-kafka/
  source_user_password = "" # Set a password for the Apache Kafka® user.

  # Target Managed Service for Elasticsearch cluster settings:
  target_admin_password = "" # Set a password for the Elasticsearch admin.

  # Specify these settings ONLY AFTER the clusters are created. Then run "terraform apply" command again.
  # You should set up endpoints using the GUI to obtain their IDs.
  source_endpoint_id = "" # Set the source endpoint ID.
  target_endpoint_id = "" # Set the target endpoint ID.
  transfer_enabled   = 0  # Set to 1 to enable Transfer.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka® and Elasticsearch clusters"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "clusters-security-group" {
  description = "Security group for the Managed Service for Apache Kafka and Managed Service for Elasticsearch clusters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® cluster from the Internet"
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow connections to the Managed Service for Elasticsearch cluster from the Internet with Kibana"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow connections to the Managed Service for Elasticsearch cluster from the Internet"
    protocol       = "TCP"
    port           = 9200
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
  description        = "Managed Service for Apache Kafka® cluster"
  name               = "kafka-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.clusters-security-group.id]

  config {
    brokers_count    = 1
    version          = local.source_kf_version
    zones            = ["ru-central1-a"]
    assign_public_ip = true # Required for connection from the Internet
    kafka {
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 10 # GB
      }
    }
  }

  user {
    name     = "mkf-user"
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

# Managed Service for Apache Kafka® topic.
resource "yandex_mdb_kafka_topic" "sensors" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = "sensors"
  partitions         = 2
  replication_factor = 1
}

resource "yandex_mdb_elasticsearch_cluster" "Elasticsearch-cluster" {
  description        = "Managed Service for Elasticsearch cluster"
  name               = "elasticsearch-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.clusters-security-group.id]

  config {
    admin_password = local.target_admin_password
    data_node {
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-ssd"
        disk_size          = 10 # GB
      }
    }
  }

  host {
    name             = "Data"
    zone             = "ru-central1-a"
    type             = "DATA_NODE"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}

resource "yandex_datatransfer_transfer" "mkf-mes-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for Apache Kafka® to the Managed Service for Elasticsearch"
  name        = "transfer-from-mkf-to-mes"
  source_id   = local.source_endpoint_id
  target_id   = local.target_endpoint_id
  type        = "INCREMENT_ONLY" # Replication data.
}
