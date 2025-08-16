# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster and Application Load Balancer Ingress Controller.
#
# EN: https://cloud.yandex.com/en/docs/managed-kubernetes/tutorials/alb-ingress-controller
# RU: https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/alb-ingress-controller
#
# Set the configuration for the Managed Service for Kubernetes cluster:

locals {
  folder_id                      = ""              # Set your cloud folder ID.
  k8s_cluster_sa_name            = "k8s-sa"        # Set the name for Managed Service for Kubernetes cluster service account.
  k8s_version                    = ""              # Set the Kubernetes version.
  zone_a_v4_cidr_blocks_subnet   = "10.101.0.0/24" # Subnet in the ru-central1-a availability zone
  zone_a_v4_cidr_blocks_cluster  = "10.1.0.0/16"   # CIDR for the cluster.
  zone_a_v4_cidr_blocks_services = "172.16.0.0/16" # CIDR for services.
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
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_subnet]
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Security group for the Managed Service for Kubernetes cluster and node groups"
  name        = "k8s-main-sg"
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    protocol       = "TCP"
    description    = "Rule allows availability checks from load balancer's address range. It is required for the operation of a fault-tolerant cluster and load balancer services"
    v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description       = "Allow the master-node and node-node interaction within the security group"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "Allow the pod-pod and service-service interaction in the subnet"
    protocol       = "ANY"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks_services]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description = "Allow receipt of debugging ICMP packets from internal subnets"
    protocol    = "ICMP"
    v4_cidr_blocks = [
      local.zone_a_v4_cidr_blocks_subnet,
      local.zone_a_v4_cidr_blocks_cluster,
      local.zone_a_v4_cidr_blocks_services
    ]
  }

  ingress {
    description    = "Allow connection to Kubernetes API on 6443 port from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    description    = "Allow connection to Kubernetes API on 443 port from the Internet"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  egress {
    description    = "Allow any outgoing traffic from the cluster"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

variable "k8s-sa-roles" {
  description = "Required roles for the Managed Service for Kubernetes service account"
  type        = set(string)
  default = [
    "alb.editor",
    "certificate-manager.certificates.downloader",
    "compute.viewer",
    "container-registry.images.puller",
    "editor",
    "vpc.publicAdmin"
  ]
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Managed Service for Kubernetes cluster and node group"
  name        = local.k8s_cluster_sa_name
}

resource "yandex_resourcemanager_folder_iam_binding" "k8s-sa-roles" {
  folder_id = local.folder_id
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]

  # Assing with cycle all required roles to service account.
  for_each = var.k8s-sa-roles
  role     = each.value
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description              = "Managed Service for Kubernetes cluster"
  name                     = "k8s-cluster"
  network_id               = yandex_vpc_network.k8s-network.id
  cluster_ipv4_range       = local.zone_a_v4_cidr_blocks_cluster
  service_ipv4_range       = local.zone_a_v4_cidr_blocks_services
  node_ipv4_cidr_mask_size = 24
  service_account_id       = yandex_iam_service_account.k8s-sa.id
  node_service_account_id  = yandex_iam_service_account.k8s-sa.id

  master {
    version = local.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.k8s-sa-roles
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for the Managed Service for Kubernetes cluster"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  name        = "k8s-node-group"
  version     = local.k8s_version

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
    platform_id = "standard-v2" # Intel Cascade Lake

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.subnet-a.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
    }

    resources {
      memory = 4 # GB
      cores  = 4 # vCPU cores
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # GB
    }
  }

  depends_on = [
    yandex_kubernetes_cluster.k8s-cluster,
    yandex_resourcemanager_folder_iam_binding.k8s-sa-roles
  ]
}
