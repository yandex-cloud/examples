# Infrastructure for the Yandex Cloud Managed Service for Redis sharded cluster and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-redis/tutorials/redis-as-php-sessions-storage
# EN: https://cloud.yandex.com/en/docs/managed-redis/tutorials/redis-as-php-sessions-storage
#
# Set the following settings:

locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  zone_b_v4_cidr_blocks = "10.2.0.0/16" # Set the CIDR block for subnet in the ru-central1-b availability zone.
  zone_c_v4_cidr_blocks = "10.3.0.0/16" # Set the CIDR block for subnet in the ru-central1-c availability zone.
  password              = ""            # Set the password for the Managed Service for Redis cluster.
  version               = "6.2"         # Set the version of the Redis.
  image_id              = ""            # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username           = ""            # Set the username to connect to the routing VM via SSH. For Ubuntu images `ubuntu` username is used by default.
  vm_ssh_key_path       = ""            # Set the path to the public SSH public key for the routing VM. Example: "~/.ssh/key.pub".
}

resource "yandex_vpc_network" "redis-and-vm-network" {
  description = "Network for the Managed Service for Redis cluster and VM"
  name        = "redis-and-vm-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_subnet" "subnet-b" {
  description    = "Subnet in the ru-central1-b availability zone"
  name           = "subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = [local.zone_b_v4_cidr_blocks]
}

resource "yandex_vpc_subnet" "subnet-c" {
  description    = "Subnet in the ru-central1-c availability zone"
  name           = "subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = [local.zone_c_v4_cidr_blocks]
}

resource "yandex_vpc_default_security_group" "redis-and-vm-security-group" {
  description = "Security group for the Managed Service for Redis cluster and VM"
  network_id  = yandex_vpc_network.redis-and-vm-network.id

  ingress {
    description    = "Allow incoming HTTP connections from the Internet"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming HTTPS connections from the Internet"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming connections to cluster from the Internet"
    protocol       = "TCP"
    port           = 6379
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

resource "yandex_mdb_redis_cluster" "redis-cluster" {
  description        = "Managed Service for Redis cluster"
  name               = "redis-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.redis-and-vm-network.id
  security_group_ids = [yandex_vpc_default_security_group.redis-and-vm-security-group.id]
  sharded            = true

  config {
    password = local.password
    version  = local.version
  }

  resources {
    resource_preset_id = "hm2.nano"
    disk_type_id       = "network-ssd"
    disk_size          = 16 # GB
  }

  host {
    zone       = "ru-central1-a"
    subnet_id  = yandex_vpc_subnet.subnet-a.id
    shard_name = "shard1"
  }

  host {
    zone       = "ru-central1-b"
    subnet_id  = yandex_vpc_subnet.subnet-b.id
    shard_name = "shard2"
  }

  host {
    zone       = "ru-central1-c"
    subnet_id  = yandex_vpc_subnet.subnet-c.id
    shard_name = "shard3"
  }
}

# Compute Virtual Machine
resource "yandex_compute_instance" "lamp-vm" {

  name        = "lamp-vm"
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
