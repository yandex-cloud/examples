# Infrastructure for the Yandex Cloud Managed Service for Apache Kafka®, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mkf-to-mkf
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mkf-to-mkf

# Set source and target cluster settings.
locals {
  # Source Managed Service for Apache Kafka® cluster settings:
  source_kf_version    = ""   # Set the Apache Kafka® version.
  source_user_name     = ""   # Set a username in the Managed Service for Apache Kafka® cluster.
  source_user_password = ""   # Set a password for the user in the Managed Service for Apache Kafka® cluster.

  # Target Managed Service for Apache Kafka® cluster settings:
  target_kf_version = "" # Set the Apache Kafka® version.

  # Specify these settings ONLY AFTER the YDB database is created. Then run "terraform apply" command again.
  # You should set up the target endpoint using the GUI to obtain its ID.
  source_endpoint_id = "" # Set the source endpoint id.
  target_endpoint_id = "" # Set the target endpoint id.

  # Transfer settings:
  transfer_enabled = 0 # Value '0' disables creating of transfer before the target endpoint is created manually. After that, set to '1' to enable transfer.
}

resource "yandex_vpc_network" "mkf_network" {
  description = "Network for the Managed Service for Apache Kafka® clusters"
  name        = "mkf_network"
}

resource "yandex_vpc_subnet" "mkf_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for the Managed Service for Apache Kafka® clusters network"
  name           = "mkf_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mkf_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mkf_security_group" {
  description = "Security group for the Managed Service for Apache Kafka® clusters"
  network_id  = yandex_vpc_network.mkf_network.id
  name        = "mkf-security-group"

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

resource "yandex_mdb_kafka_cluster" "mkf-cluster-source" {
  description        = "Managed Service for Apache Kafka® cluster"
  environment        = "PRODUCTION"
  name               = "mkf-cluster-source"
  network_id         = yandex_vpc_network.mkf_network.id
  security_group_ids = [yandex_vpc_security_group.mkf_security_group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = local.source_kf_version
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB
      }
    }

    zones = [
      "ru-central1-a"
    ]
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

# Source Managed Service for Apache Kafka® topic
resource "yandex_mdb_kafka_topic" "sensors-source" {
  cluster_id         = yandex_mdb_kafka_cluster.mkf-cluster-source.id
  name               = "sensors"
  partitions         = 3
  replication_factor = 1
}

resource "yandex_mdb_kafka_cluster" "mkf-cluster-target" {
  description        = "Managed Service for Apache Kafka® cluster"
  environment        = "PRODUCTION"
  name               = "mkf-cluster-target"
  network_id         = yandex_vpc_network.mkf_network.id
  security_group_ids = [yandex_vpc_security_group.mkf_security_group.id]

  config {
    brokers_count    = 1
    version          = local.target_kf_version
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB
      }
    }

    zones = [
      "ru-central1-a"
    ]
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

# Target Managed Service for Apache Kafka® topic
resource "yandex_mdb_kafka_topic" "sensors-target" {
  cluster_id         = yandex_mdb_kafka_cluster.mkf-cluster-target.id
  name               = "sensors"
  partitions         = 1
  replication_factor = 1
}

resource "yandex_datatransfer_transfer" "mkf-mkf-transfer" {
   count       = local.transfer_enabled
   description = "Transfer between the Managed Service for Apache Kafka® clusters"
   name        = "transfer-from-mkf-to-mkf"
   source_id   = local.source_endpoint_id
   target_id   = local.target_endpoint_id
   type        = "INCREMENT_ONLY" # Replicate data from the source Apache Kafka® topic.
 }
