# Infrastructure for Yandex Cloud Managed Service for Greenplum® cluster, Ubuntu VM, and Object Storage bucket
#
# RU: https://cloud.yandex.ru/docs/managed-greenplum/tutorials/config-server-for-s3
# EN: https://cloud.yandex.com/en/docs/managed-greenplum/tutorials/config-server-for-s3
#
# Specify the following settings:
# * Virtual Machine
#     * Image ID: https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
#     * OpenSSH public key
# * Managed Service for Greenplum® cluster:
#     * password for `user` account
# * Yandex Object Storage:
#     * cloud folder ID, same as for provider
#     * unique bucket name

# Network
resource "yandex_vpc_network" "mgp_network" {
  name        = "mgp_network"
  description = "Network for Managed Service for Greenplum®"
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mgp_network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

# Security group for Managed Service for Greenplum®
resource "yandex_vpc_security_group" "mgp_security_group" {
  network_id = yandex_vpc_network.mgp_network.id
  name = "Managed Greenplum® security group"

  ingress {
    protocol       = "ANY"
    description    = "Allow incoming traffic from members of the same security group"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing traffic to members of the same security group"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for Greenplum®
resource "yandex_mdb_greenplum_cluster" "mgp-cluster" {
  name               = "mgp-cluster"
  description        = "Managed Greenplum® cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mgp_network.id
  zone               = "ru-central1-a"
  subnet_id          = yandex_vpc_subnet.subnet-a.id
  assign_public_ip   = true
  version            = "6.19"
  master_host_count  = 2
  segment_host_count = 2
  segment_in_host    = 1
  master_subcluster {
    resources {
      resource_preset_id = "s2.medium"
      disk_size          = 100
      disk_type_id       = "local-ssd"
    }
  }
  segment_subcluster {
    resources {
      resource_preset_id = "s2.medium"
      disk_size          = 100
      disk_type_id       = "local-ssd"
    }
  }

  user_name     = "user"
  user_password = "" # Set password

  security_group_ids = [yandex_vpc_security_group.mgp_security_group.id]
}

# Virtual machine with Ubuntu 20.04
resource "yandex_compute_instance" "vm-ubuntu-20-04" {

  name               = "vm-ubuntu-20-04"
  platform_id        = "standard-v1"
  zone               = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true
    security_group_ids = [yandex_vpc_security_group.mgp_security_group.id]
  }

  metadata = {
    # Set username and path for SSH public key
    # For Ubuntu images `ubuntu` username is used by default
    ssh-keys = "<username>:${file("<full path>")}"
  }
}

# Yandex Object Storage bucket

locals {
  folder_id = "" # Set your cloud folder ID
}

# Create a service account
resource "yandex_iam_service_account" "sa-for-obj-storage" {
  folder_id = local.folder_id
  name      = "sa-for-obj-storage"
}

# Grant permissions to the service account
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa-for-obj-storage.id}"
}

# Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa-for-obj-storage.id
  description        = "Static access key for Object Storage"
}

# Use keys to create a bucket
resource "yandex_storage_bucket" "obj-storage-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "" #Set a unique bucket name
}

# Place an object into the bucket
resource "yandex_storage_object" "example-table" {
  bucket = yandex_storage_bucket.obj-storage-bucket.bucket
  access_key = yandex_storage_bucket.obj-storage-bucket.access_key
  secret_key = yandex_storage_bucket.obj-storage-bucket.secret_key
  key    = "example.csv"
  source = "./example.csv"
}

# Prepare outputs for access_key and secret_key
output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa-static-key.access_key
}

output "secret_key" {
  value = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  sensitive = true
}
