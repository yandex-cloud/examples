# Infrastructure for two Data Proc clusters and two Object Storage buckets
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/dataproc-to-dataproc
# EN: https://cloud.yandex.com/en/docs/data-proc/tutorials/dataproc-to-dataproc
#
# Set the configuration of the Data Proc clusters and Object Storage buckets

# Specify the following settings:
locals {
  folder_id = "" # Your cloud folder ID, same as for provider
  input_bucket  = "" # Name of an Object Storage bucket for input files. Must be unique in the Cloud.
  output_bucket = "" # Name of an Object Storage bucket for output files. Must be unique in the Cloud.
  dp_ssh_key = "" # Аn absolute path to the SSH public key for the Data Proc cluster

  # The following settings are predefined. Change them only if necessary.
  network_name = "dataproc-network" # Name of the network
  nat_name = "dataproc-nat" # Name of the NAT gateway
  subnet_name = "dataproc-subnet-a" # Name of the subnet
  dp_sa_name = "dataproc-sa" # Name of the service account for DataProc
  os_sa_name = "sa-for-obj-storage" # Name of the service account for Object Storage creating
  dataproc_source_name = "dataproc-source-cluster" # Name of the Data Proc source cluster
  dataproc_target_name = "dataproc-target-cluster" # Name of the Data Proc target cluster
}

resource "yandex_vpc_network" "dataproc_network" {
  description = "Network for Data Proc"
  name        = local.network_name
}

# NAT gateway for Data Proc
resource "yandex_vpc_gateway" "dataproc_nat" {
  name = local.nat_name
  shared_egress_gateway {}
}

# Route table for Data Proc
resource "yandex_vpc_route_table" "dataproc_rt" {
  network_id = yandex_vpc_network.dataproc_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.dataproc_nat.id
  }
}

resource "yandex_vpc_subnet" "dataproc_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for Data Proc and Managed Service for ClickHouse"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.dataproc_network.id
  v4_cidr_blocks = ["10.140.0.0/24"]
  route_table_id = yandex_vpc_route_table.dataproc_rt.id
}

resource "yandex_vpc_security_group" "dataproc-security-group" {
  description = "Security group for the Data Proc cluster"
  network_id  = yandex_vpc_network.dataproc_network.id

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
    description    = "Allow connections to the Metastore port from any IP address"
    protocol       = "ANY"
    port           = 9083
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_iam_service_account" "dataproc-sa" {
  description = "Service account to manage the Data Proc cluster"
  name        = local.dp_sa_name
}

# Assign the `dataproc.agent` role to the Data Proc service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = local.folder_id
  role      = "mdb.dataproc.agent"
  members = ["serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"]
}

# Yandex Object Storage bucket

# Create a service account for Object Storage creating
resource "yandex_iam_service_account" "sa-for-obj-storage" {
  folder_id = local.folder_id
  name      = local.os_sa_name
}

# Grant the service account storage.admin role to create storages and grant bucket ACLs
resource "yandex_resourcemanager_folder_iam_binding" "s3-editor" {
  folder_id = local.folder_id
  role      = "storage.admin"
  members = ["serviceAccount:${yandex_iam_service_account.sa-for-obj-storage.id}"]
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
    id = yandex_iam_service_account.dataproc-sa.id
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
    id = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ", "WRITE"]
  }
}

resource "yandex_dataproc_cluster" "dataproc-source-cluster" {
  description        = "Data Proc source cluster"
  depends_on         = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket             = yandex_storage_bucket.output-bucket.id
  security_group_ids = [yandex_vpc_security_group.dataproc-security-group.id]
  name               = local.dataproc_source_name
  service_account_id = yandex_iam_service_account.dataproc-sa.id
  zone_id            = "ru-central1-a"
  ui_proxy           = true

  cluster_config {
    version_id = "2.0"

    hadoop {
      services        = ["HIVE", "SPARK", "YARN"]
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
      subnet_id   = yandex_vpc_subnet.dataproc_subnet-a.id
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
      subnet_id   = yandex_vpc_subnet.dataproc_subnet-a.id
      hosts_count = 1
    }
  }
}

resource "yandex_dataproc_cluster" "dataproc-target-cluster" {
  description        = "Data Proc target cluster"
  depends_on         = [yandex_resourcemanager_folder_iam_binding.dataproc-agent]
  bucket             = yandex_storage_bucket.output-bucket.id
  security_group_ids = [yandex_vpc_security_group.dataproc-security-group.id]
  name               = local.dataproc_target_name
  service_account_id = yandex_iam_service_account.dataproc-sa.id
  zone_id            = "ru-central1-a"
  ui_proxy           = true

  cluster_config {
    version_id = "2.0"

    hadoop {
      services        = ["HIVE", "SPARK", "YARN"]
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
      subnet_id   = yandex_vpc_subnet.dataproc_subnet-a.id
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
      subnet_id   = yandex_vpc_subnet.dataproc_subnet-a.id
      hosts_count = 1
    }
  }
}
