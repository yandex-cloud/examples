# Infrastructure for Yandex Cloud Managed Service for Apache Kafka clusters with Kafka Connect
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/kafka-connect
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/kafka-connect
#
# Set the user name and SSH key for virtual machine
#
# Set a password for Managed Service for Apache Kafka

# Network
resource "yandex_vpc_network" "kafka_network" {
  name        = "kafka_network"
  description = "Network for Managed Service for Apache Kafka"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "kafka-subnet-a" {
  name           = "kafka-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.kafka_network.id
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
      image_id = "fd879gb88170to70d38a"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.kafka-subnet-a.id
    nat       = true
  }

  metadata = {
    # Set username and path for SSH public key
    # For Ubuntu images used `ubuntu` username by default
    ssh-keys = "<username>:${file("path for SSH public key")}"
  }
}

# Security group for Managed Service for Apache Kafka
resource "yandex_vpc_security_group" "kafka_security_group" {
  name       = "kafka_security_group"
  network_id = yandex_vpc_network.kafka_network.id

  ingress {
    description    = "Kafka"
    port           = 9091
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for Apache Kafka
resource "yandex_mdb_kafka_cluster" "tutorial_kafka_cluster" {
  environment        = "PRODUCTION"
  name               = "tutorial_kafka_cluster"
  network_id         = yandex_vpc_network.kafka_network.id
  security_group_ids = [yandex_vpc_security_group.kafka_security_group.id]

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
    name     = "tutorial-user"
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

# Kafka topic
resource "yandex_mdb_kafka_topic" "messages" {
  cluster_id         = yandex_mdb_kafka_cluster.tutorial_kafka_cluster.id
  name               = "messages"
  partitions         = 1
  replication_factor = 1
}
