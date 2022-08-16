# Infrastructure for Yandex Cloud Managed Service for Apache Kafka® clusters with Kafka Connect
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/kafka-connect
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/kafka-connect
#
# Set the following settings:

locals {
  image_id        = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username     = "" # Set the username to connect to the routing VM via SSH. For Ubuntu images `ubuntu` username is used by default.
  vm_ssh_key_path = "" # Set the path to the public SSH public key for the routing VM. Example: "~/.ssh/key.pub".
  password        = "" # Set the password for the username "user" in Managed Service for Apache Kafka® cluster.
}

resource "yandex_vpc_network" "kafka-connect-network" {
  description = "Network for the Managed Service for Apache Kafka® cluster"
  name        = "kafka-connect-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "kafka-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.kafka-connect-network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

resource "yandex_compute_instance" "vm-ubuntu-20-04" {
  description = "Virtual machine with Ubuntu 20.04"
  name        = "vm-ubuntu-20-04"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
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
    ssh-keys = "local.vm_username:${file(local.vm_ssh_key_path)}"
  }
}

# Security group for the Managed Service for Apache Kafka® cluster
resource "yandex_vpc_default_security_group" "kafka-connect-security-group" {
  network_id = yandex_vpc_network.kafka-connect-network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® broker hosts from the Internet"
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® schema registry from the Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow SSH connections to VM from the Internet"
    protocol       = "TCP"
    port           = 22
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

resource "yandex_mdb_kafka_cluster" "kafka-connect-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
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
    password = local.password
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
