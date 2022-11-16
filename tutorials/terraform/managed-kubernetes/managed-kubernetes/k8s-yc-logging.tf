# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster with Fluent Bit extension.
# https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/fluent-bit-logging
# Set the configuration of the Managed Service for Kubernetes cluster.

locals {
  folder_id             = ""            # Set your cloud folder ID.
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet.
  lg_name               = ""            # Set the logging group name.
  sa_name               = ""            # Set the name for the Managed Kubernetes service account.
  fb_sa_name            = ""            # Set the name for the Fluent Bit service account.
  lg_period             = "5h"          # Set the retention period for the logging group.
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = "k8s-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Security group for the Managed Service for Kubernetes cluster"
  name        = "k8s-main-sg"
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description       = "The rule allows availability checks from the load balancer's range of addresses"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks" # The load balancer's address range.
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description       = "The rule allows the master-node and node-node interaction within the security group"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "The rule allows the pod-pod and service-service interaction"
    protocol       = "ANY"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description    = "The rule allows receipt of debugging ICMP packets from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
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
    description    = "The rule allows all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Managed Service for Kubernetes cluster and node group"
  name        = local.sa_name
}

resource "yandex_iam_service_account" "fb-sa" {
  description = "Service account for the Fluent Bit"
  name        = local.fb_sa_name
}

data "yandex_resourcemanager_folder" "cloud-folder" {
  folder_id = local.folder_id # Folder ID required for binding roles to service account.
}

# Assign "editor" role the cluster service account.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = data.yandex_resourcemanager_folder.cloud-folder.id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "container-registry.images.puller" role to cluster service account.
resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = data.yandex_resourcemanager_folder.cloud-folder.id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "logging.writer" role to Fluent Bit service account.
resource "yandex_resourcemanager_folder_iam_binding" "logging-writer" {
  folder_id = data.yandex_resourcemanager_folder.cloud-folder.id
  role      = "logging.writer"
  members = [
    "serviceAccount:${yandex_iam_service_account.fb-sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = "k8s-cluster"
  network_id  = yandex_vpc_network.k8s-network.id

  master {
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
  name        = "k8s-node-group"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id

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
      cores  = 4 # Number of CPU cores.
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # GB
    }
  }
}

resource "yandex_logging_group" "group" {
  name             = local.lg_name
  folder_id        = local.folder_id
  retention_period = local.lg_period
  depends_on       = [yandex_resourcemanager_folder_iam_binding.logging-writer]
}
