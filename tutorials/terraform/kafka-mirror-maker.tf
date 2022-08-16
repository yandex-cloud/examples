# Infrastructure for Yandex Cloud Managed Service for Apache Kafka® cluster and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
# EN: https://cloud.yandex.com/en/docs/managed-kafka/tutorials/mirrormaker-unmanaged-topics
#
# Set the following settings:

locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  username              = ""            # Set the admin username in Managed Service for Apache Kafka® cluster.
  password              = ""            # Set the admin password Managed Service for Apache Kafka® cluster.
  image_id              = ""            # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username           = ""            # Set the username to connect to the routing VM via SSH. For Ubuntu images `ubuntu` username is used by default.
  vm_ssh_key_path       = ""            # Set the path to the public SSH public key for the routing VM. Example: "~/.ssh/key.pub".
}


resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka® cluster and VM"
  name        = "network"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

# Security group for the Managed Service for Apache Kafka® cluster and VM
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the Managed Service for Apache Kafka® cluster from the Internet"
    protocol       = "TCP"
    from_port      = 9091
    to_port        = 9092
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH connections for VM
  ingress {
    description    = "Allow SSH connections for VM from the Internet"
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

resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  description        = "Yandex Managed Service for Apache Kafka® cluster"
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
    name     = local.username
    password = local.password
    permission {
      topic_name = "*"
      role       = "ACCESS_ROLE_ADMIN"
    }
  }
}

resource "yandex_compute_instance" "vm-mirror-maker" {
  description = "VM in Yandex Compute Cloud"
  name        = "vm-mirror-maker"
  platform_id = "standard-v3" # Intel Ice Lake

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
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "local.vm_username:${file(local.vm_ssh_key_path)}"
  }
}
