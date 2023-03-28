# Infrastructure for the Yandex Cloud Managed Service for ClickHouse, Data Proc, and Object Storage
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/s3-dataproc-ch
# EN: https://cloud.yandex.com/en/docs/data-proc/tutorials/s3-dataproc-ch
#
# Set the configuration of the Managed Service for ClickHouse cluster, Data Proc cluster, and Object Storage

# Specify the following settings
locals {
  folder_id = "" # Your cloud folder ID, same as for provider

  input-bucket  = "" # Name of an Object Storage bucket for input files. Must be unique in the Cloud
  output-bucket = "" # Name of an Object Storage bucket for output files. Must be unique in the Cloud

  dp_ssh_key = "" # Set an absolute path to the SSH public key for the Data Proc cluster

  ch_password = "" # A user password for the ClickHouse cluster
}

resource "yandex_vpc_network" "dataproc_ch_network" {
  description = "Network for Data Proc and Managed Service for ClickHouse"
  name        = "dataproc_ch_network"
}

# NAT gateway for Data Proc
resource "yandex_vpc_gateway" "dataproc_nat" {
  name = "dataproc-nat"
  shared_egress_gateway {}
}

# Route table for Data Proc
resource "yandex_vpc_route_table" "dataproc-rt" {
  network_id = yandex_vpc_network.dataproc_ch_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.dataproc_nat.id
  }
}

resource "yandex_vpc_subnet" "dataproc_ch_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for Data Proc and Managed Service for ClickHouse"
  name           = "dataproc_ch_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.dataproc_ch_network.id
  v4_cidr_blocks = ["10.140.0.0/24"]
  route_table_id = yandex_vpc_route_table.dataproc-rt.id
}

resource "yandex_vpc_security_group" "dataproc-security-group" {
  description = "Security group for the Data Proc cluster"
  network_id  = yandex_vpc_network.dataproc_ch_network.id

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
    description    = "Allow connections to the HTTPS port from any IP address"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow connections to the ClickHouse port from any IP address"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mch_security_group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.dataproc_ch_network.id

  ingress {
    description    = "Allow SSL connections to the Managed Service for ClickHouse cluster with clickhouse-client"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS connections to the Managed Service for ClickHouse cluster"
    protocol       = "TCP"
    port           = 8443
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

resource "yandex_iam_service_account" "dataproc-sa" {
  description = "Service account to manage the Data Proc cluster"
  name        = "dataproc-sa"
}

# Assign the `dataproc.agent` role to the Data Proc service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = local.folder_id
  role      = "dataproc.agent"
  members   = ["serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"]
}

# Yandex Object Storage bucket

# Create a service account for Object Storage creation
resource "yandex_iam_service_account" "sa-for-obj-storage" {
  folder_id = local.folder_id
  name      = "sa-for-obj-storage"
}

# Grant the service account storage.admin role to create storages and grant bucket ACLs
resource "yandex_resourcemanager_folder_iam_binding" "s3-editor" {
  folder_id = local.folder_id
  role      = "storage.admin"
  members   = ["serviceAccount:${yandex_iam_service_account.sa-for-obj-storage.id}"]
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  description        = "Static access key for Object Storage"
  service_account_id = yandex_iam_service_account.sa-for-obj-storage.id
}

# Use keys to create an input bucket and grant permission to Data Proc service account to read from the bucket
resource "yandex_storage_bucket" "input-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.input-bucket

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ"]
  }
}

# Use keys to create an output bucket and grant permission to Data Proc service account to read from the bucket and write to it
resource "yandex_storage_bucket" "output-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.output-bucket

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ", "WRITE"]
  }
}

resource "yandex_dataproc_cluster" "dataproc-cluster" {
  description        = "Data Proc cluster"
  depends_on         = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket             = yandex_storage_bucket.output-bucket.id
  name               = "dataproc-cluster"
  service_account_id = yandex_iam_service_account.dataproc-sa.id
  zone_id            = "ru-central1-a"
  ui_proxy           = true

  cluster_config {
    version_id = "2.0"

    hadoop {
      services        = ["HDFS", "SPARK", "YARN"]
      ssh_public_keys = [file(local.dp_ssh_key)]
    }

    subcluster_spec {
      name = "main"
      role = "MASTERNODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = yandex_vpc_subnet.dataproc_ch_subnet-a.id
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
      subnet_id   = yandex_vpc_subnet.dataproc_ch_subnet-a.id
      hosts_count = 1
    }
  }
}

resource "yandex_mdb_clickhouse_cluster" "mch-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "mch-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.dataproc_ch_network.id
  security_group_ids = [yandex_vpc_security_group.mch_security_group.id]

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
    subnet_id        = yandex_vpc_subnet.dataproc_ch_subnet-a.id
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
