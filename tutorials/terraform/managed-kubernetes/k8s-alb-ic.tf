# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster and Application Load Balancer Ingress Controller
#
# Set the configuration of Managed Service for Kubernetes cluster

locals {
  folder_id              = ""            # Set your cloud folder ID
  k8s_node_group_version = "1.21"        # Set the version of Kubernetes for the node group
  k8s_cluster_version    = "1.21"        # Set the version of Kubernetes for the master host
  zone_a_v4_cidr_blocks  = "10.1.0.0/16" # Set the CIDR block for the Subnet in ru-central1-a availability zone
}

# Network
resource "yandex_vpc_network" "k8s-network" {
  name        = "k8s-network"
  description = "Network for the Managed Service for Kubernetes cluster"
}

# Subnet
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  description    = "Subnet in ru-central1-a availability zone"
  zone           = "yandex_vpc_subnet.subnet-a.zone"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for the Managed Service for Kubernetes cluster
resource "yandex_vpc_security_group" "k8s-main-sg" {
  name        = "k8s-main-sg"
  description = "Group rules ensure the basic performance of the cluster. Apply it to the cluster and node groups."
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    protocol       = "TCP"
    description    = "The rule allows availability checks from the load balancer's range of addresses. It is required for the operation of a fault-tolerant cluster and load balancer services."
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"] # The load balancer's address range
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "The rule allows incoming TCP-connections on ports 10501 and 10502 from the load balancer's range of addresses."
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"] # The load balancer's address range
    from_port      = 10501
    to_port        = 10502
  }

  ingress {
    protocol          = "ANY"
    description       = "The rule allows the master-node and node-node interaction within the security group."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    description    = "The rule allows the pod-pod and service-service interaction. Specify the subnets of your cluster and services."
    v4_cidr_blocks = ["10.1.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    protocol       = "ICMP"
    description    = "The rule allows receipt of debugging ICMP packets from internal subnets."
    v4_cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    protocol       = "TCP"
    description    = "The rule allows connection to Kubernetes API on 6443 port from the Internet."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "The rule allows connection to Kubernetes API on 443 port from the Internet."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    protocol       = "ANY"
    description    = "The rule allows all outgoing traffic. Nodes can connect to Yandex Container Registry, Object Storage, Docker Hub, and more."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  name        = "k8s-sa"
  description = "Service account for Kubernetes cluster and node group"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  # Assign "editor" role to service account.
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  # Assign "container-registry.images.puller" role to service account.
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name        = "k8s-cluster"
  description = "Managed Service for Kubernetes cluster"
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = "locals.k8s_cluster_version"
    zonal {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # Node group service account ID
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  name        = "k8s-node-group"
  description = "Node group for the Managed Service for Kubernetes cluster"
  version     = local.k8s_node_group_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = "yandex_vpc_subnet.subnet-a.zone"
    }
  }

  instance_template {
    platform_id = "standard-v2" # Intel Cascade Lake

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.subnet-a.id]
    }

    resources {
      memory = 4 # GB
      cores  = 4 # Number of CPU cores
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # GB
    }
  }
}