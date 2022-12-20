# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster and virtual machine
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-rabbitmq
#
# Set the following settings:

locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  db_username           = ""            # Set database username.
  db_password           = ""            # Set database user password.
  image_id              = ""            # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username           = ""            # Set the username to connect to the routing VM via SSH. For Ubuntu images `ubuntu` username is used by default.
  vm_ssh_key_path       = ""            # Set the path to the public SSH public key for the routing VM. Example: "~/.ssh/key.pub".
}

resource "yandex_vpc_network" "clickhouse-and-vm-network" {
  description = "Network for the Managed Service for ClickHouse cluster and VM"
  name        = "clickhouse-and-vm-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse-and-vm-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_default_security_group" "clickhouse-and-vm-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster and VM"
  network_id  = yandex_vpc_network.clickhouse-and-vm-network.id

  ingress {
    description    = "Allow incoming connections to cluster from any network"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming connections to RabbitMQ from any network"
    protocol       = "TCP"
    port           = 5672
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming SSH connections to VM from the Internet"
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

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
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
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = "db1"
  }

  user {
    name     = local.db_username
    password = local.db_password
    permission {
      database_name = "db1"
    }
  }
}

# VM in Yandex Compute Cloud
resource "yandex_compute_instance" "vm-1" {

  name        = "linux-vm"
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
