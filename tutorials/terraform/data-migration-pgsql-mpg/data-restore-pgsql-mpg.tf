# Infrastructure for Yandex Cloud Managed Service for PostgreSQL cluster and Virtual Machine.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-postgresql/tutorials/data-migration

# Specify the following settings:
locals {
  # Managed Service for PostgreSQL cluster.
  target_pgsql_version = "" # Set the PostgreSQL version. It must be the same as the version of the source cluster.
  target_db_name       = "" # Set the target cluster database name.
  target_user          = "" # Set the target cluster username. It must be the same as the username of the source cluster.
  target_password      = "" # Set the target cluster user password.
  # (Optional) Virtual Machine.
  vm_image_id   = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username   = "" # Set a username for VM. Images with Ubuntu Linux use the username `ubuntu` by default.
  vm_public_key = "" # Set a full path to SSH public key.
}

# Source cluster PostgreSQL extensions to be enabled in the Managed Service for PostgreSQL cluster:
variable "pg-extensions" {
  description = "List of extensions for the Managed Service for PostgreSQL cluster"
  type        = set(string)
  default = [
    # Put the list of the source database PostgreSQL extensions.
    # Example:
    # "pg_qualstats",
    # "dblink"
  ]
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for PostgreSQL cluster and VM"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

resource "yandex_vpc_security_group" "security-group-mpg" {
  description = "Security group for the Managed Service for PostgreSQL cluster"
  network_id  = yandex_vpc_network.network.id
}

resource "yandex_vpc_security_group_rule" "rule-cluster" {
  security_group_binding = yandex_vpc_security_group.security-group-mpg.id
  direction              = "ingress"
  description            = "Allow connections to the cluster from the Internet"
  protocol               = "TCP"
  port                   = 6432
  v4_cidr_blocks         = ["0.0.0.0/0"]
}

# If you use VM for loading database dump and restoring data to the cluster, uncomment these lines.
#resource "yandex_vpc_security_group" "security-group-vm" {
#  description = "Security group for VM"
#  network_id  = yandex_vpc_network.network.id
#}
#
#resource "yandex_vpc_security_group_rule" "rule-vm-in" { 
#  security_group_binding = yandex_vpc_security_group.security-group-vm.id
#  direction              = "ingress"
#  description            = "Allow SSH connections for VM from the Internet"
#  protocol               = "TCP"
#  port                   = 22
#  v4_cidr_blocks         = ["0.0.0.0/0"]
#}
#
#resource "yandex_vpc_security_group_rule" "rule-vm-out" {
#  security_group_binding = yandex_vpc_security_group.security-group-vm.id
#  direction              = "egress"
#  description            = "Allow outgoing connections to any required resource"
#  protocol               = "ANY"
#  from_port              = 0
#  to_port                = 65535
#  v4_cidr_blocks         = ["0.0.0.0/0"]
#}

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = "mpg-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group-mpg.id]

  config {
    version = local.target_pgsql_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-hdd"
      disk_size          = 10 # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet, for a method without an intermediate VM.
  }
}

# A PostgreSQL database of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_database" "database" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.target_db_name

  # Set the names of PostgreSQL extensions with cycle.
  dynamic "extension" {
    for_each = var.pg-extensions
    content {
      name = extension.value
    }
  }
}

# A PostgreSQL user of the Managed Service for PostgreSQL cluster.
resource "yandex_mdb_postgresql_user" "user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.target_user
  password   = local.target_password
  permission {
    database_name = local.target_db_name
  }
  grants = ["ALL"]
}

# If you use VM for loading database dump and restoring data to the cluster, uncomment these lines.
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
#      yandex_vpc_security_group.security-group-mpg.id,
#      yandex_vpc_security_group.security-group-vm.id
#    ]
#  }
#
#  metadata = {
#    ssh-keys = "local.vm_username:${file(local.vm_public_key)}" # Username and SSH public key full path.
#  }
#}
