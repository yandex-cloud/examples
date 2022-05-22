# Infrastructure for Yandex Cloud Managed Service for Apache Kafka® clusters with Kafka Connect
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/kafka-connect
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/kafka-connect
#
# Set setting:
# * Virtual Machine
#     * Image ID: https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
#     * OpenSSH public key
# * Managed Service for Apache Kafka® cluster:
#     * password for `user` account

# Network
resource "yandex_vpc_network" "kafka-connect-network" {
  name        = "kafka-connect-network"
  description = "Network for Managed Service for Apache Kafka® cluster"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "kafka-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.kafka-connect-network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

# Virtual machine with Ubuntu 20.04
resource "yandex_compute_instance" "vm-ubuntu-20-04" {

  name        = "vm-ubuntu-20-04"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      # How to list available images list:
      # https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
      image_id = ""
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-a.id
    nat                = true
    security_group_ids = [yandex_vpc_default_security_group.kafka-connect-security-group.id]
  }

  metadata = {
    # Set username and path for SSH public key
    # For Ubuntu images used `ubuntu` username by default
    ssh-keys = "<username>:${file("path for SSH public key")}"
  }
}

# Security group for Managed Service for Apache Kafka® cluster
resource "yandex_vpc_default_security_group" "kafka-connect-security-group" {
  network_id = yandex_vpc_network.kafka-connect-network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to Managed Service for Apache Kafka® broker hosts from the Internet"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to Managed Service for Apache Kafka® schema registry from the Internet"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH connections to VM from the Internet"
    port           = 22
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
resource "yandex_mdb_kafka_cluster" "kafka-connect-cluster" {
  environment        = "PRODUCTION"
  name               = "kafka-connect-cluster"
  network_id         = yandex_vpc_network.kafka-connect-network.id
  security_group_ids = [yandex_vpc_default_security_group.kafka-connect-security-group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = "2.8"
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
    name     = "user"
    password = "" # Set password
    permission {
      topic_name = "messages"
      role       = "ACCESS_ROLE_CONSUMER"
    }
    permission {
      topic_name = "messages"
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }
}

# Managed Service for Apache Kafka® topic
resource "yandex_mdb_kafka_topic" "messages" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-connect-cluster.id
  name               = "messages"
  partitions         = 1
  replication_factor = 1
}
