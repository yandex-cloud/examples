# Infrastructure for Yandex Cloud Managed Service for MySQL cluster and Virtual Machine.
#
# RU: https://cloud.yandex.ru/docs/managed-mysql/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-mysql/tutorials/data-migration
#
# Set the following settings:
locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/24" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  # Managed Service for MySQL cluster.
  target_mysql_version = "" # Set the MySQL version. It must be the same or higher than the version in the source cluster.
  target_sql_mode      = "" # Set the MySQL SQL mode. It must be the same as in the source cluster.
  target_db_name       = "" # Set the target cluster database name.
  target_user          = "" # Set the target cluster username.
  target_password      = "" # Set the target cluster password.
  # (Optional) Virtual Machine.
  vm_image_id   = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username   = "" # Set a username for VM. Images with Ubuntu Linux use the username `ubuntu` by default.
  vm_public_key = "" # Set a full path to SSH public key.
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for MySQL cluster and VM"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "security-group-mysql" {
  description = "Security group for the Managed Service for MySQL cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = 3306
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

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = local.target_mysql_version
  security_group_ids = [yandex_vpc_security_group.security-group-mysql.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  mysql_config = {
    sql_mode = local.target_sql_mode
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet. For a method without intermediate VM.
  }

  database {
    name = local.target_db_name
  }

  user {
    name     = local.target_user
    password = local.target_password
    permission {
      database_name = local.target_db_name
      roles         = ["ALL"]
    }
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
#      yandex_vpc_security_group.security-group-mysql.id,
#      yandex_vpc_security_group.security-group-vm.id
#    ]
#  }
#
#  metadata = {
#    ssh-keys = "${local.vm_username}:${file(local.vm_public_key)}" # Username and SSH public key full path.
#  }
#}
