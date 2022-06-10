# Infrastructure for Yandex Data Proc cluster with NAT instance.
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/configure-network
# EN: https://cloud.yandex.com/en-ru/docs/data-proc/tutorials/configure-network


# Set the following settings:
locals {
  folder_id              = ""                     # Yout folder ID. Required for binding roles to service account.
  path_to_ssh_public_key = ""                     # Set a full path to SSH public key. NAT instance use username `ubuntu` by default.
  data_proc_sa_name      = ""                     # Set name for service account for the Data Proc cluster.
  nat_instance_image_id  = "fd82fnsvr0bgt1fid7cl" # Image ID for NAT instance. See https://cloud.yandex.ru/marketplace/products/yc/nat-instance-ubuntu-18-04-lts for details.
  cidr_internet          = "0.0.0.0/0"            # All IPv4 addresses.
}

resource "yandex_vpc_network" "network-data-proc" {
  description = "Network for Data Proc cluster and NAT instance"
  name        = "network-data-proc"
}

resource "yandex_vpc_subnet" "subnet-cluster" {
  description    = "Subnet for the Data Proc cluster"
  name           = "subnet-cluster"
  network_id     = yandex_vpc_network.network-data-proc.id
  v4_cidr_blocks = ["192.168.1.0/24"]
  zone           = "ru-central1-a"
  route_table_id = yandex_vpc_route_table.route-table-nat.id
}

resource "yandex_vpc_subnet" "subnet-nat" {
  description    = "Subnet for NAT instance"
  name           = "subnet-nat"
  network_id     = yandex_vpc_network.network-data-proc.id
  v4_cidr_blocks = ["192.168.100.0/24"]
  zone           = "ru-central1-b"
}

resource "yandex_vpc_security_group" "sg-internet" {
  description = "Allow any outgoing traffic to the Internet"
  name        = "sg-internet"
  network_id  = yandex_vpc_network.network-data-proc.id

  egress {
    description    = "Allow any outgoing traffic to the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }
}

resource "yandex_vpc_security_group" "sg-data-proc-cluster" {
  description = "Security group for the Yandex Data Proc cluster"
  name        = "sg-data-proc-cluster"
  network_id  = yandex_vpc_network.network-data-proc.id

  ingress {
    description       = "Allow any traffic within one security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

resource "yandex_vpc_security_group" "sg-nat-instance" {
  description = "Security group for the NAT instance"
  name        = "sg-nat-instance"
  network_id  = yandex_vpc_network.network-data-proc.id

  ingress {
    description    = "Allow any outgoing traffic from the Yandex Data Proc cluster"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }

  ingress {
    description    = "Allow SSH connections to NAT instance"
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

resource "yandex_iam_service_account" "dataproc-sa" {
  description = "Service account for the Yandex Data Proc cluster"
  name        = local.data_proc_sa_name
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-sa-role-dataproc-agent" {
  # Bind role `mdb.dataproc.agent` to the service account. Required for creation of Data Proc cluster.
  folder_id = local.folder_id
  role      = "mdb.dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_dataproc_cluster" "dataproc-cluster" {
  description        = "Yandex Data Proc cluster"
  name               = "dataproc-cluster"
  service_account_id = yandex_iam_service_account.dataproc-sa.id
  zone_id            = "ru-central1-a"

  security_group_ids = [
    yandex_vpc_security_group.sg-internet.id,         # Allow any outgoing traffic to the Internet.
    yandex_vpc_security_group.sg-data-proc-cluster.id # Allow connections from VM and inside security group.
  ]

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
      subnet_id   = yandex_vpc_subnet.subnet-cluster.id
      hosts_count = 1 # For MASTERNODE only one hosts assigned.

      resources {
        resource_preset_id = "s2.micro"    # 4 vCPU Intel Cascade, 16 GB RAM.
        disk_type_id       = "network-ssd" # Fast network SSD storage.
        disk_size          = 20            # GB
      }
    }

    subcluster_spec {
      name        = "subcluster-data"
      role        = "DATANODE"
      subnet_id   = yandex_vpc_subnet.subnet-cluster.id
      hosts_count = 2

      resources {
        resource_preset_id = "s2.micro"    # 4 vCPU, 16 GB RAM.
        disk_type_id       = "network-hdd" # Standard network HDD storage.
        disk_size          = 20            # GB
      }
    }
  }
}

resource "yandex_compute_instance" "nat-instance-vm" {
  description = "NAT instance VM"
  name        = "nat-instance-vm"
  platform_id = "standard-v3" # Intel Ice Lake
  zone        = "ru-central1-b"

  resources {
    cores  = 2 # vCPU
    memory = 4 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.nat_instance_image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-nat.id
    nat       = true # Required for connection from the Internet.

    security_group_ids = [
      yandex_vpc_security_group.sg-internet.id,    # Allow any outgoing traffic to Internet.
      yandex_vpc_security_group.sg-nat-instance.id # Allow connections to and from Data Proc cluster.
    ]
  }

  metadata = {
    ssh-keys = "${file(local.path_to_ssh_public_key)}"
  }
}

resource "yandex_vpc_route_table" "route-table-nat" {
  description = "Route table for Data Proc cluster subnet" # All requests can be forwarded to the NAT instance IP address.
  name        = "route-table-nat"

  depends_on = [
    yandex_compute_instance.nat-instance-vm
  ]

  network_id = yandex_vpc_network.network-data-proc.id

  static_route {
    destination_prefix = local.cidr_internet
    next_hop_address   = yandex_compute_instance.nat-instance-vm.network_interface.0.ip_address
  }
}
