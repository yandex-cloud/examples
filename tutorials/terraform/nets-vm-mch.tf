# Infrastructure for the Yandex Cloud Managed Service for ClickHouse, virtual machines (VMs) and DNS zone.
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/dns-peering
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/dns-peering
#
# Specify the following settings.
locals {
  # Cluster settings:
  ch_dbname         = "" # Set the ClickHouse cluster database name.
  ch_user           = "" # Set the username for ClickHouse database.
  ch_password       = ""    # Set the user password for ClickHouse database.

  # VM settings
  image_id              = ""            # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username           = ""            # Set the username to connect to the routing VM via SSH. For Ubuntu images `ubuntu` username is used by default.
  vm_ssh_key_path       = ""            # Set the path to the public SSH public key for the routing VM. Example: "~/.ssh/key.pub".
  create_optional_vm = 0 # Set to 1 to create optional VM.

  # DNS zone settings:
  create_zone = 0 # Set to 1 to create DNS zone.
}

resource "yandex_vpc_network" "mch-net" {
  description = "Network for the Managed Service for ClickHouse cluster"
  name        = "mch-net"
}

resource "yandex_vpc_subnet" "mch-subnet-a" {
  description    = "Subnet of the mch-net in the ru-central1-a availability zone"
  name           = "mch-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mch-net.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_network" "vm-net" {
  description = "Network for the Virtual Machine"
  name        = "vm-net"
}

resource "yandex_vpc_subnet" "vm-subnet-a" {
  description    = "Subnet of the vm-net in the ru-central1-a availability zone"
  name           = "vm-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.vm-net.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_vpc_security_group" "mch-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.mch-net.id

  ingress {
    description    = "The rule allows connections with a ClickHouse client to the Managed Service for ClickHouse cluster from Compute Cloud VMs"
    protocol       = "TCP"
    port           = 8123
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "The rule allows SSH connections to VMs"
    protocol       = "TCP"
    port           = 22
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

resource "yandex_vpc_security_group" "vm-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.vm-net.id

  ingress {
    description    = "The rule allows SSH connections to VMs"
    protocol       = "TCP"
    port           = 22
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

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mch-net.id
  security_group_ids = [yandex_vpc_security_group.mch-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mch-subnet-a.id
    assign_public_ip = false
  }

  database {
    name = local.ch_dbname
  }

  user {
    name     = local.ch_user
    password = local.ch_password
    permission {
      database_name = local.ch_dbname
    }
  }
}

# VM in Yandex Compute Cloud located in mch-net
resource "yandex_compute_instance" "mch-net-vm" {

  count = local.create_optional_vm
  name        = "linux-vm-internal"
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
    subnet_id = yandex_vpc_subnet.mch-subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "local.vm_username:${file(local.vm_ssh_key_path)}"
  }
}

# VM in Yandex Compute Cloud located in vm-net
resource "yandex_compute_instance" "another-net-vm" {

  name        = "linux-vm-external"
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
    subnet_id = yandex_vpc_subnet.vm-subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "local.vm_username:${file(local.vm_ssh_key_path)}"
  }
}

resource "yandex_dns_zone" "dns-zone" {
  count = local.create_zone
  name             = "demo-private-zone"
  description      = "ClickHouse DNS zone"
  zone             = "mdb.yandexcloud.net."
  public           = false
  private_networks = [yandex_vpc_network.mch-net.id, yandex_vpc_network.vm-net.id]
}
