# Infrastructure for Yandex Cloud Managed Service for Apache Kafka clusters with Kafka Connect
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/kafka-connect
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/kafka-connect
#
# Set the user name and SSH key for virtual machine
#
# Set the user name and password for Managed Service for Apache Kafka

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

  resources {
    cores  = 32
    memory = 1
  }

  boot_disk {
    initialize_params {
      image_id = "fd81hgrcv6lsnkremf32"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.kafka-subnet-a.id
    nat       = true
  }

  metadata = {
    ssh-keys = "<user name>:<public SSH>" # Specify the user name and public SSH key
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
        disk_size          = 10
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro"
      }
    }

    zones = [
      "ru-central1-a"
    ]
  }

  user {
    name     = "" # Set the user name
    password = "" # Set a password
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

resource "yandex_mdb_kafka_topic" "messages" {
  cluster_id         = yandex_mdb_kafka_cluster.tutorial_kafka_cluster.id
  name               = "messages"
  partitions         = 1
  replication_factor = 1
}

# Kafka Connect
resource "yandex_mdb_kafka_connector" "tutorial_kafka_connector" {
  cluster_id = yandex_mdb_kafka_cluster.tutorial_kafka_cluster.id
  name       = "tutorial_kafka_connector"
}
