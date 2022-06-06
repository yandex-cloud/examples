# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster, Data Proc cluster and virtual machine.
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/exchange-data-with-mch
#
# Set the configuration of the Managed Service for ClickHouse cluster, Data Proc cluster and Virtual Machine.

# Specify the pre-installation parameters:
locals {
  folder_id          = ""                                                # Your Folder ID.
  network_id         = ""                                                # Network ID for Managed Service for ClickHouse cluster, Data Proc cluster and VM.
  subnet_id          = ""                                                # Subnet ID (enable NAT for this subnet).
  ch_password        = ""                                                # Set user password for ClickHouse cluster.
  vm_ssh_keys        = "<username>:${file("<path to public key file>")}" # Set username and SSH public key path for VM.
  vm_image_id        = "fd8ciuqfa001h8s9sa7i"                            # Ubuntu 20.04. See this page to list all available images: https://cloud.yandex.ru/docs/compute/operations/images-with-pre-installed-software/get-list.
  dp_ssh_public_keys = [file("<path to public key file>")]               # Set SSH public key path for Data Proc Cluster.
  bucket_name        = ""                                                # Name for the Object Storage bucket. Should be unique in Cloud.
}

resource "yandex_vpc_security_group" "clickhouse-and-vm-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster and VM."
  network_id  = local.network_id

  ingress {
    description    = "Allow SSL connections to the Managed Service for ClickHouse cluster with clickhouse-client."
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS connections to the Managed Service for ClickHouse cluster."
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow SSH connections to VM from the Internet."
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource."
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "data-proc-security-group" {
  description = "Security group for the Data Proc cluster."
  network_id  = local.network_id

  ingress {
    description       = "Inbound internal traffic rules."
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description       = "Outbound internal traffic rules."
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Allow connections to the HTTPS port."
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_iam_service_account" "dataproc" {
  description = "Service account to manage the Dataproc cluster."
  name        = "dataproc"
}

data "yandex_resourcemanager_folder" "my-folder" {
  folder_id = local.folder_id
}

# Roles to create Data Proc cluster.
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = data.yandex_resourcemanager_folder.my-folder.id
  role      = "dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-provisioner" {
  folder_id = data.yandex_resourcemanager_folder.my-folder.id
  role      = "dataproc.provisioner"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc.id}",
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "monitoring-viewer" {
  folder_id = data.yandex_resourcemanager_folder.my-folder.id
  role      = "monitoring.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc.id}",
  ]
}

# Role to create Object Storage Bucket
resource "yandex_resourcemanager_folder_iam_binding" "bucket-creator" {
  folder_id = data.yandex_resourcemanager_folder.my-folder.id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc.id}",
  ]
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = local.network_id
  security_group_ids = [yandex_vpc_security_group.clickhouse-and-vm-security-group.id]

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
    subnet_id        = local.subnet_id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = "db1"
  }

  user {
    name     = "user1"
    password = local.ch_password
    permission {
      database_name = "db1"
    }
  }
}

# VM in Yandex Compute Cloud
resource "yandex_compute_instance" "vm-1" {
  name        = "linux-vm"
  platform_id = "standard-v3" # Intel Ice Lake
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.vm_image_id
    }
  }

  network_interface {
    subnet_id          = local.subnet_id
    security_group_ids = [yandex_vpc_security_group.clickhouse-and-vm-security-group.id]
    nat                = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = local.vm_ssh_keys
  }
}

# Object Storage bucket static key
resource "yandex_iam_service_account_static_access_key" "my-bucket-key" {
  service_account_id = yandex_iam_service_account.dataproc.id
}

# Object Storage bucket
resource "yandex_storage_bucket" "my-bucket" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.bucket-creator
  ]

  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.my-bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.my-bucket-key.secret_key
}

resource "yandex_dataproc_cluster" "my-dp-cluster" {
  description = "Dataproc cluster."
  depends_on  = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket      = yandex_storage_bucket.my-bucket.bucket
  name        = "my-dp-cluster"
  labels = {
    created_by = "terraform"
  }
  service_account_id = yandex_iam_service_account.dataproc.id
  zone_id            = "ru-central1-a"
  ui_proxy           = true

  cluster_config {
    version_id = "2.0"

    hadoop {
      services = ["HBASE", "HDFS", "YARN", "SPARK", "TEZ", "MAPREDUCE", "HIVE", "ZEPPELIN", "ZOOKEEPER"]
      properties = {
        "yarn:yarn.resourcemanager.am.max-attempts" = 5
      }
      ssh_public_keys = local.dp_ssh_public_keys
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

    subcluster_spec {
      name = "compute_static"
      role = "COMPUTENODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = local.subnet_id
      hosts_count = 1
    }

    subcluster_spec {
      name = "compute_autoscaling"
      role = "COMPUTENODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = local.subnet_id
      hosts_count = 1
      autoscaling_config { # All settings in seconds
        max_hosts_count        = 10
        measurement_duration   = 60
        warmup_duration        = 60
        stabilization_duration = 120
        preemptible            = false
        decommission_timeout   = 60
      }
    }
  }
}