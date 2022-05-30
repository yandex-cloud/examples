# Infrastructure for Yandex Data Proc cluster with NAT instance
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/configure-network
# EN: https://cloud.yandex.com/en-ru/docs/data-proc/tutorials/configure-network

locals {
  # Required settings for Data Proc cluster and NAT instance
  folder_id              = ""          # Set your folder ID. Required for binding roles to service account
  path_to_ssh_public_key = ""          # Set a full path to SSH public key
  network_id             = ""          # Set an ID of network for Data Proc cluster and NAT instance
  subnet_id              = ""          # Set an ID if subnet with enabled NAT
  cidr_internet          = "0.0.0.0/0" # All IPv4 addresses
}



resource "yandex_vpc_security_group" "sg-internet" {
  name        = "sg-internet"
  description = "Security group allow any outgoing traffic to Internet. Used by Yandex Data Proc cluster and NAT instance."
  network_id  = local.network_id

  egress {
    description    = "Allow any outgoing traffic to Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }
}

resource "yandex_vpc_security_group" "sg-data-proc-cluster" {
  name        = "sg-data-proc-cluster"
  description = "Security group for the Yandex Data Proc cluster"
  network_id  = local.network_id

  ingress {
    description       = "Allow any traffic within one security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

resource "yandex_vpc_security_group" "sg-nat-instance" {
  name        = "sg-nat-instance"
  description = "Security group for the NAT instance"
  network_id  = local.network_id

  ingress {
    description    = "Allow any outgoing traffic from the Yandex Data Proc cluster"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }

  ingress {
    description    = "Allow incoming SSH connections to NAT instance"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [local.cidr_internet]
  }

  ingress {
    description       = "Allow connections from Data Proc cluster"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

resource yandex_vpc_route_table "route-table" {
  network_id = yandex_vpc_network.data-proc-cluster-network.id
}

resource "yandex_iam_service_account" "dataproc-sa" {
  name        = "maxdunaevsky-dataproc-sa"
  description = "Service account for the Yandex Data Proc cluster"
}

data "yandex_resourcemanager_folder" "cloud-folder" {
  # Folder ID required for binding roles to service account
  folder_id = local.folder_id
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-sa-role-dataproc-agent" {
  # Bind role `dataproc.agent` to service account. Required for creation of Data Proc cluster
  folder_id = data.yandex_resourcemanager_folder.cloud-folder.id
  role      = "mdb.dataproc.agent"

  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_dataproc_cluster" "dataproc-cluster" {

  name               = "dataproc-cluster"
  description        = "Yandex Data Proc cluster"
  service_account_id = yandex_iam_service_account.dataproc-sa.id # Required role `dataproc.agent`

  security_group_ids = [
    yandex_vpc_security_group.sg-internet.id,         # Allow any outgoing traffic to Internet
    yandex_vpc_security_group.sg-data-proc-cluster.id # Allow connections from VM and inside security group
  ]

  zone_id = "ru-central1-a"

  cluster_config {
    hadoop {
      services = ["HDFS", "YARN", "SPARK", "TEZ", "MAPREDUCE", "HIVE"]
      ssh_public_keys = [
        file(local.path_to_ssh_public_key)
      ]
    }

    subcluster_spec {
      name        = "subcluster-master"
      role        = "MASTERNODE"
      subnet_id   = local.subnet_id
      hosts_count = 1 # For MASTERNODE only one hosts assigned

      resources {
        resource_preset_id = "s2.small"    # 4 vCPU Intel Cascade, 16 GB RAM
        disk_type_id       = "network-ssd" # Fast network SSD disk
        disk_size          = 20            # GB
      }
    }

    subcluster_spec {
      name        = "subcluster-data"
      role        = "DATANODE"
      subnet_id   = local.subnet_id
      hosts_count = 2 #

      resources {
        resource_preset_id = "s2.small" # 4 vCPU, 16 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 100 # GB
      }
    }
  }
}

resource "yandex_compute_instance" "nat-instance" {

  description = "NAT instance VM"
  name        = "nat-instance"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2 # vCPU
    memory = 4 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "fd82fnsvr0bgt1fid7cl" # ID of NAT instance image
    }
  }

  network_interface {
    subnet_id = local.subnet_id
    nat       = true # Required for connection from the Internet

    security_group_ids = [
      yandex_vpc_security_group.sg-internet.id,    # Allow any outgoing traffic to Internet
      yandex_vpc_security_group.sg-nat-instance.id # Allow connections to and from Data Proc cluster
    ]
  }

  metadata = {
    ssh-keys = file(local.path_to_ssh_public_key)
  }
}
