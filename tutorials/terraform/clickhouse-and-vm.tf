# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster and virtual machine
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq
#
# Set the user name and password for Managed Service for ClickHouse cluster
# Set the user name and SSH-key for Virtual Machine


# Network
resource "yandex_vpc_network" "clickhouse-and-vm-network" {
  name        = "clickhouse-and-vm-network"
  description = "Network for Managed Service for ClickHouse cluster and VM."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse-and-vm-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for Managed Service for ClickHouse cluster and VM
resource "yandex_vpc_default_security_group" "clickhouse-and-vm-security-group" {
  network_id = yandex_vpc_network.clickhouse-and-vm-network.id

  # Allow connections to cluster from Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 8123
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 9000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "TCP"
    description    = "Allow connections from Internet"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connections for VM
  ingress {
    protocol       = "TCP"
    description    = "Allow connections for VM"
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

# Managed Service for ClickHouse cluster
resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.clickhouse-and-vm-network.id
  security_group_ids = [yandex_vpc_default_security_group.clickhouse-and-vm-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from Internet
  }

  database {
    name = "db1"
  }

  user {
    name     = "" # Set username for ClickHouse cluster
    password = "" # Set user password for ClickHouse cluster
    permission {
      database_name = "db1"
    }
  }
}

# Compute Virtual Machine
resource "yandex_compute_instance" "vm-1" {

  name        = "linux-vm"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd879gb88170to70d38a"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # Required for connection from Internet
  }

  metadata = {
    ssh-keys = ":" # Set username:SSH-key for VM
  }
}
