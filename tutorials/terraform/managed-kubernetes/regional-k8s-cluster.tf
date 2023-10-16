# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster
#
# Set the configuration of Managed Service for Kubernetes cluster:
locals {
  folder_id   = "" # Your cloud folder ID, same as for the Yandex Cloud provider
  k8s_version = "" # Desired version of Kubernetes. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-kubernetes/concepts/release-channels-and-updates.

  # The following settings are predefined. Change them only if necessary.
  sa_name_k8s               = "k8s-sa-reg-mig" # Service account name for a Kubernetes cluster
  network_name              = "k8s-network" # Name of the network
  subnet_name-a             = "my-subnet-a" # Name of the subnet in the ru-central1-a availability zone
  subnet_name-b             = "my-subnet-b" # Name of the subnet in the ru-central1-b availability zone
  subnet_name-c             = "my-subnet-c" # Name of the subnet in the ru-central1-c availability zone
  zone_a_v4_cidr_blocks_a   = "10.1.0.0/16" # CIDR block for the subnet in the ru-central1-a availability zone
  zone_a_v4_cidr_blocks_b   = "172.16.0.0/24" # CIDR block for the subnet in the ru-central1-b availability zone
  zone_a_v4_cidr_blocks_c   = "192.168.0.0/24" # CIDR block for the subnet in the ru-central1-c availability zone
  main_security_group_name  = "k8s-main-sg" # Name of the main security group of the cluster
  public_services_sg_name   = "k8s-public-services" # Name of the public services security group for node groups
  k8s_cluster_name          = "k8s-cluster" # Name of the Kubernetes cluster
  k8s_node_group_name       = "k8s-node-group" # Name of the Kubernetes node group
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = local.network_name
}

resource "yandex_vpc_subnet" "my-subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = local.subnet_name-a
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_a]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
}

resource "yandex_vpc_subnet" "my-subnet-b" {
  description    = "Subnet in the ru-central1-b availability zone"
  name           = local.subnet_name-b
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_b]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.k8s-network.id
}

resource "yandex_vpc_subnet" "my-subnet-c" {
  description    = "Subnet in the ru-central1-c availability zone"
  name           = local.subnet_name-c
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_c]
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.k8s-network.id
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Security group ensure the basic performance of the cluster. Apply it to the cluster and node groups."
  name        = local.main_security_group_name
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description    = "The rule allows availability checks from the load balancer's range of addresses. It is required for the operation of a fault-tolerant cluster and load balancer services."
    protocol       = "TCP"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"] # The load balancer's address range
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description       = "The rule allows the master-node and node-node interaction within the security group"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "The rule allows the pod-pod and service-service interaction. Specify the subnets of your cluster and services."
    protocol       = "ANY"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_a]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description    = "The rule allows receipt of debugging ICMP packets from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_a]
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 6443 port from specified network"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 443 port from specified network"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    description    = "The rule allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Object Storage, Docker Hub, and more."
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  description = "Security group allows connections to services from the internet. Apply the rules only for node groups."
  name        = local.public_services_sg_name
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description    = "The rule allows incoming traffic from the internet to the NodePort port range. Add ports or change existing ones to the required ports."
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Kubernetes cluster"
  name        = local.sa_name_k8s
}

# Assign role "editor" to the Kubernetes service account
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign role "container-registry.images.puller" to the Kubernetes service account
resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = local.k8s_cluster_name
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = local.k8s_version
    public_ip = true
    regional {
      region = "ru-central1"
      location {
        zone      = yandex_vpc_subnet.my-subnet-a.zone
        subnet_id = yandex_vpc_subnet.my-subnet-a.id
      }
      location {
        zone      = yandex_vpc_subnet.my-subnet-b.zone
        subnet_id = yandex_vpc_subnet.my-subnet-b.id
      }
      location {
        zone      = yandex_vpc_subnet.my-subnet-c.zone
        subnet_id = yandex_vpc_subnet.my-subnet-c.id
      }
    }
    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s-sa.id # ID of the service account for the cluster
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # ID of the service account for the node group
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for Managed Service for Kubernetes cluster"
  name        = local.k8s_node_group_name
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = local.k8s_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.my-subnet-a.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id, yandex_vpc_security_group.k8s-public-services.id]
    }

    resources {
      memory = 4 # RAM quantity in GB
      cores  = 4 # Number of CPU cores
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # Disk size in GB
    }
  }
}
