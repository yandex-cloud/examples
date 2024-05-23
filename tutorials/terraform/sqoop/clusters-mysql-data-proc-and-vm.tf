# Infrastructure for the Yandex Cloud Managed Service for MySQL® cluster, Data Proc cluster, and Virtual Machine
#
# RU: https://yandex.cloud/ru/docs/managed-mysql/tutorials/sqoop
# EN: https://yandex.cloud/en/docs/managed-mysql/tutorials/sqoop
#
# Set the configuration of the Managed Service for MySQL® cluster, Managed Service for Data Proc cluster, and Virtual Machine:
locals {
  folder_id           = ""      # Your folder ID
  network_id          = ""      # Network ID for the Managed Service for MySQL® cluster, Data Proc cluster, and VM
  subnet_id           = ""      # Subnet ID (enable NAT for this subnet)
  storage_sa_id       = ""      # Service account ID for creating a bucket in Object Storage
  data_proc_sa        = ""      # Data Proc service account name. It must be unique in the folder.
  my_cluster_version  = "8.0"   # MySQL® version: 5.7 or 8.0
  my_cluster_db       = "db1"   # Database name
  my_cluster_username = "user1" # Database owner's name
  my_cluster_password = ""      # Database owner's password
  vm_image_id         = ""      # Public image ID from https://yandex.cloud/en/docs/compute/operations/images-with-pre-installed-software/get-list
  vm_username         = ""      # Username for VM. Images with Ubuntu Linux use the `ubuntu` username by default.
  vm_public_key       = ""      # Full path to the SSH public key for VM
  bucket_name         = ""      # Object Storage bucket name. It must be unique throughout Object Storage.
  dp_public_key       = ""      # Full path to the SSH public key for the Data Proc Cluster
}

# Security groups for the Managed Service for MySQL® cluster, Data Proc cluster, and VM

resource "yandex_vpc_security_group" "cluster-security-group" {
  description = "Security group for the Managed Service for MySQL® cluster"
  network_id  = local.network_id

  ingress {
    description    = "Allow connections to the cluster from the Internet"
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "vm-security-group" {
  description = "Security group for the VM"
  network_id  = local.network_id

  ingress {
    description    = "Allow SSH connections to VM from the Internet"
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

resource "yandex_vpc_security_group" "data-proc-security-group" {
  description = "Security group for the Data Proc cluster"
  network_id  = local.network_id

  ingress {
    description       = "Allow any incoming traffic within the security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description       = "Allow any outgoing traffic within the security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Allow connections to the HTTPS port"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# The service account for the Data Proc cluster

resource "yandex_iam_service_account" "data-proc-sa" {
  description = "Service account to manage the Data Proc cluster"
  name        = local.data_proc_sa
}

# Assign the `dataproc.agent` role to the service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = local.folder_id
  role      = "dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.data-proc-sa.id}",
  ]
}

# Assign the `dataproc.provisioner` role to the service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-provisioner" {
  folder_id = local.folder_id
  role      = "dataproc.provisioner"
  members = [
    "serviceAccount:${yandex_iam_service_account.data-proc-sa.id}",
  ]
}

# Assign the `monitoring-viewer` role to the service account
resource "yandex_resourcemanager_folder_iam_binding" "monitoring-viewer" {
  folder_id = local.folder_id
  role      = "monitoring.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.data-proc-sa.id}",
  ]
}

# Assign the `storage.viewer` role to the service account
resource "yandex_resourcemanager_folder_iam_binding" "bucket-viewer" {
  folder_id = local.folder_id
  role      = "storage.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.data-proc-sa.id}",
  ]
}

# Assign the `storage.uploader` role to the service account
resource "yandex_resourcemanager_folder_iam_binding" "bucket-uploader" {
  folder_id = local.folder_id
  role      = "storage.uploader"
  members = [
    "serviceAccount:${yandex_iam_service_account.data-proc-sa.id}",
  ]
}

# Infrastructure for the Managed Service for MySQL cluster

resource "yandex_mdb_mysql_cluster" "mysql-cluster" {
  description        = "Managed Service for MySQL® cluster"
  name               = "mysql-cluster"
  environment        = "PRODUCTION"
  network_id         = local.network_id
  version            = local.my_cluster_version
  security_group_ids = [yandex_vpc_security_group.cluster-security-group.id]

  resources {
    resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
    disk_type_id       = "network-hdd"
    disk_size          = "10" # GB
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = local.subnet_id
  }
}

# Database of the Managed Service for MySQL cluster
resource "yandex_mdb_mysql_database" "db1" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.my_cluster_db
}

# User of the Managed Service for MySQL cluster
resource "yandex_mdb_mysql_user" "user1" {
  cluster_id = yandex_mdb_mysql_cluster.mysql-cluster.id
  name       = local.my_cluster_username
  password   = local.my_cluster_password
  permission {
    database_name = yandex_mdb_mysql_database.db1.name
    roles         = ["ALL"]
  }
  depends_on = [
    yandex_mdb_mysql_database.db1
  ]
}

# VM infrastructure

resource "yandex_compute_instance" "vm-linux" {
  description = "Virtual Machine in Yandex Compute Cloud"
  name        = "vm-linux"
  platform_id = "standard-v3" # Intel Ice Lake
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.vm_image_id
    }
  }

  network_interface {
    subnet_id = local.subnet_id
    nat       = true # Required for connection from the Internet

    security_group_ids = [
      yandex_vpc_security_group.vm-security-group.id,
      yandex_vpc_security_group.cluster-security-group.id
    ]
  }

  metadata = {
    ssh-keys = "${local.vm_username}:${file(local.vm_public_key)}" # Username and the SSH public key full path
  }
}

# Infrastructure for the Object Storage bucket

resource "yandex_iam_service_account_static_access_key" "bucket-key" {
  description        = "Static key for the Object Storage bucket"
  service_account_id = local.storage_sa_id
}

# Object Storage bucket
resource "yandex_storage_bucket" "storage-bucket" {
  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.bucket-key.secret_key
}

# Infrastructure for the Data Proc cluster

resource "yandex_dataproc_cluster" "my-dp-cluster" {
  description        = "Data Proc cluster"
  depends_on         = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket             = yandex_storage_bucket.storage-bucket.bucket
  name               = "my-dp-cluster"
  service_account_id = yandex_iam_service_account.data-proc-sa.id
  zone_id            = "ru-central1-a"

  cluster_config {
    version_id = "1.4"

    hadoop {
      services = ["HBASE", "HDFS", "HIVE", "MAPREDUCE", "SQOOP", "YARN", "ZOOKEEPER"]
      properties = {
        "yarn:yarn.resourcemanager.am.max-attempts" = 5
        "hive:hive.execution.engine"                = "mr"
      }
      ssh_public_keys = [file(local.dp_public_key)]
    }

    subcluster_spec {
      name = "main"
      role = "MASTERNODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = local.subnet_id
      hosts_count = 1
    }

    subcluster_spec {
      name = "data"
      role = "DATANODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = local.subnet_id
      hosts_count = 1
    }
  }
}
