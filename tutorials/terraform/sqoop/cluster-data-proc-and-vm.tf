# Infrastructure for Yandex Cloud Managed Service for Data Proc cluster and Virtual machine.
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/tutorials/sqoop
#
# Set the configuration of the Managed Service for Data Proc cluster and Virtual machine:
locals {
  folder_id     = "" # Your Folder ID.
  vm_image_id   = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list.
  vm_username   = "" # Set a username for VM. Images with Ubuntu Linux use username `ubuntu` by default.
  vm_public_key = "" # Set a full path to SSH public key for VM.
  dp_public_key = "" # Set a full path to SSH public key for Data Proc Cluster.
}

resource "yandex_vpc_security_group" "vm-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster and VM"
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
    description       = "Inbound internal traffic rules"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description       = "Outbound internal traffic rules"
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

resource "yandex_iam_service_account" "bucket-sa" {
  description = "Service account to manage the Dataproc cluster"
  name        = "bucket-sa"
}

# Roles to create Data Proc cluster.
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = local.folder_id
  role      = "dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.bucket-sa.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-provisioner" {
  folder_id = local.folder_id
  role      = "dataproc.provisioner"
  members = [
    "serviceAccount:${yandex_iam_service_account.bucket-sa.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "monitoring-viewer" {
  folder_id = local.folder_id
  role      = "monitoring.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.bucket-sa.id}",
  ]
}

# Role to create Object Storage Bucket
resource "yandex_resourcemanager_folder_iam_binding" "bucket-creator" {
  folder_id = local.folder_id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.bucket-sa.id}",
  ]
}

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
    nat       = true # Required for connection from the Internet.

    security_group_ids = [yandex_vpc_security_group.vm-security-group.id,
      yandex_vpc_security_group.cluster-security-group.id
    ]
  }

  metadata = {
    ssh-keys = "local.vm_username:${file(local.vm_public_key)}" # Username and SSH public key full path.
  }
}

resource "yandex_iam_service_account_static_access_key" "my-bucket-key" {
  description        = "Object Storage bucket static key"
  service_account_id = yandex_iam_service_account.bucket-sa.id
}

# Object Storage bucket
resource "yandex_storage_bucket" "my-bucketololo" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.bucket-creator
  ]

  bucket     = "my-bucketololo"
  access_key = yandex_iam_service_account_static_access_key.my-bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.my-bucket-key.secret_key
}

resource "yandex_dataproc_cluster" "my-dp-cluster" {
  description = "Dataproc cluster"
  depends_on  = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket      = yandex_storage_bucket.my-bucketololo.bucket
  name        = "my-dp-cluster"
  labels = {
    created_by = "terraform"
  }
  service_account_id = yandex_iam_service_account.bucket-sa.id
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
