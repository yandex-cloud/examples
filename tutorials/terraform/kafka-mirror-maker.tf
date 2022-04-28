# Infrastructure for Yandex Cloud Managed Service for Kafka and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
#
# Set the configuration:
# * Managed Service for Apache Kafka cluster:
#      * admin account name
#      * admin account password
# * Virtual Machine:
#      * Image ID
#      * Path to public part of SSH key


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

# Security group for Managed Service for Kafka and VM
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

  # Allow SSH connections for VM
  ingress {
    protocol       = "TCP"
    description    = "Allow SSH connections for VM from the Internet"
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

# Managed Service for Kafka cluster
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
    name     = "" # Set admin username for Kafka cluster
    password = "" # Set admin password for Kafka cluster
    permission {
      topic_name = "*"
      role       = "ACCESS_ROLE_ADMIN"
    }
  }
}

# VM in Yandex Compute Cloud
resource "yandex_compute_instance" "vm-mirror-maker" {

  name        = "vm-mirror-maker"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "" # Set image ID
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "<username>:${file("path for SSH public key")}" # Set username and path for SSH public key
  }
}
