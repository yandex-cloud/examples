# Infrastructure for the Yandex Cloud Managed Service for Redis non-sharded cluster and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-redis/tutorials/redis-as-php-sessions-storage
# EN: https://cloud.yandex.com/en/docs/managed-redis/tutorials/redis-as-php-sessions-storage
#
# Specify the following settings:
locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  # Managed Service for Redis cluster.
  redis_version = "6.2" # Set the Redis version.
  password      = ""    # Set the cluster password.
  # (Optional) Virtual Machine.
  vm_image_id   = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username   = "" # Set a username for VM. Images with Ubuntu Linux use the username `ubuntu` by default.
  vm_public_key = "" # Set a full path to SSH public key.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Redis cluster and VM"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "security-group-redis" {
  description = "Security group for the Managed Service for Redis cluster"
  network_id  = yandex_vpc_network.network.id

  # Required for clusters created with TLS
  ingress {
    description    = "Allow direct connections to the master with SSL"
    protocol       = "TCP"
    port           = 6380
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Required for clusters created without TLS
  #ingress {
  #  description    = "Allow direct connections to the master without SSL"
  #  protocol       = "TCP"
  #  port           = 6379
  #  v4_cidr_blocks = ["0.0.0.0/0"]
  #}

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to the Redis Sentinel"
    port           = 26379
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# If you use VM for connection to the cluster, uncomment these lines.
#resource "yandex_vpc_security_group" "security-group-vm" {
#  description = "Security group for VM"
#  network_id  = yandex_vpc_network.network.id
#
#  ingress {
#    description    = "Allow SSH connections for VM from the Internet"
#    protocol       = "TCP"
#    port           = 22
#    v4_cidr_blocks = ["0.0.0.0/0"]
#  }
#
#  egress {
#    description    = "Allow outgoing connections to any required resource"
#    protocol       = "ANY"
#    from_port      = 0
#    to_port        = 65535
#    v4_cidr_blocks = ["0.0.0.0/0"]
#  }
#}

resource "yandex_mdb_redis_cluster" "redis-cluster" {
  description        = "Security group for the Managed Service for Redis cluster"
  name               = "redis-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group-redis.id]
  tls_enabled        = true # TLS support mode. Must be enabled for public access to the cluster host. For a method without VM.

  config {
    password = local.password
    version  = local.redis_version
  }

  resources {
    resource_preset_id = "hm2.nano" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-ssd"
    disk_size          = 16 # GB
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet. For a method without VM.
  }
}

# If you use VM for connection to the cluster, uncomment these lines.
#resource "yandex_compute_instance" "vm-linux" {
#  description = "Virtual Machine in Yandex Compute Cloud"
#  name        = "vm-linux"
#  platform_id = "standard-v3" # Intel Ice Lake
#
#  resources {
#    cores  = 2
#    memory = 2 # GB
#  }
#
#  boot_disk {
#    initialize_params {
#      image_id = local.vm_image_id
#    }
#  }
#
#  network_interface {
#    subnet_id = yandex_vpc_subnet.subnet-a.id
#    nat       = true # Required for connection from the Internet.
#
#    security_group_ids = [
#      yandex_vpc_security_group.security-group-redis.id,
#      yandex_vpc_security_group.security-group-vm.id
#    ]
#  }
#
#  metadata = {
#    ssh-keys = "local.vm_username:${file(local.vm_public_key)}" # Username and SSH public key full path.
#  }
#}
