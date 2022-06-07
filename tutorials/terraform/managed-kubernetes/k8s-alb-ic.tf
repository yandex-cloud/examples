# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster and Application Load Balancer Ingress Controller.
# EN: https://cloud.yandex.com/en/docs/managed-kubernetes/tutorials/alb-ingress-controller
# RU: https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/alb-ingress-controller
#
# Set the configuration of Managed Service for Kubernetes cluster.

locals {
  folder_id              = ""            # Set your cloud folder ID.
  k8s_node_group_version = "1.20"        # Set the version of Kubernetes for the node group.
  k8s_cluster_version    = "1.20"        # Set the version of Kubernetes for the master host.
}

variable "zone_a_v4_cidr_blocks" {
  type    = string
  default = "10.1.0.0/16"
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for the Managed Service for Kubernetes cluster"
  name        = "k8s-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [var.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Group rules ensure the basic performance of the cluster, apply it to the cluster and node groups"
  name        = "k8s-main-sg"
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description       = "The rule allows availability checks from the load balancer's range of addresses, it is required for the operation of a fault-tolerant cluster and load balancer services"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description       = "The rule allows incoming TCP-connections on ports 10501 and 10502 from the load balancer's range of addresses"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 10501
    to_port           = 10502
  }

  ingress {
    description       = "The rule allows the master-node and node-node interaction within the security group"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "The rule allows the pod-pod and service-service interaction. Specify the subnets of your cluster and services"
    protocol       = "ANY"
    v4_cidr_blocks = [var.zone_a_v4_cidr_blocks]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description    = "The rule allows receipt of debugging ICMP packets from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = [var.zone_a_v4_cidr_blocks]
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 6443 port from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on 443 port from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    description    = "The rule allows all outgoing traffic, nodes can connect to Yandex Container Registry, Object Storage, Docker Hub, and more"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Managed Service for Kubernetes cluster and node group"
  name        = "k8s-sa"
}

# Assign "editor" role to service account.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "container-registry.images.puller" role to service account.
resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = "k8s-cluster"
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = local.k8s_cluster_version
    zonal {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID.
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # Node group service account ID.
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for the Managed Service for Kubernetes cluster"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  name        = "k8s-node-group"
  version     = local.k8s_node_group_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.subnet-a.zone
    }
  }

  instance_template {
    platform_id = "standard-v2" # Intel Cascade Lake.

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.subnet-a.id]
    }

    resources {
      memory = 4 # GB
      cores  = 4 # vCPU cores.
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # GB
    }
  }
}