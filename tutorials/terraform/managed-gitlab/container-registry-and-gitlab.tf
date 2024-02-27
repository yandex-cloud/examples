# Infrastructure for Yandex Container Registry and Yandex Managed Service for Kubernetes
#
# RU: https://cloud.yandex.ru/docs/managed-gitlab/tutorials/image-storage
# EN: https://cloud.yandex.com/en/docs/managed-gitlab/tutorials/image-storage
#
# Specify the following settings:
locals {
  folder_id   = "" # Set your folder ID.
  k8s_version = "" # Set a Kubernetes version.
}

resource "yandex_vpc_network" "my-net-for-gitlab" {
  name = "my-net-for-gitlab"
}

resource "yandex_vpc_subnet" "my-subnet-for-gitlab" {
  name           = "my-subnet-for-gitlab"
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.my-net-for-gitlab.id
}

resource "yandex_vpc_security_group" "gitlab-security-group" {
  name        = "gitlab-security-group"
  description = "Group rules support basic cluster functionality."
  network_id  = yandex_vpc_network.my-net-for-gitlab.id
  # Incoming traffic.
  ingress {
    protocol          = "TCP"
    description       = "The rule allows availability checks from the load balancer's address range. It is required for the operation of a fault-tolerant cluster and load balancer services."
    predefined_target = "loadbalancer_healthchecks" # The load balancer's address range.
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "The rule allows master-node and node-node communication within the security group."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "The rule allows pod-pod and service-service communication."
    v4_cidr_blocks    = concat(yandex_vpc_subnet.my-subnet-for-gitlab.v4_cidr_blocks)
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ICMP"
    description       = "The rule allows debugging ICMP packets from internal subnets."
    v4_cidr_blocks    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    protocol          = "TCP"
    description       = "The rule allows incoming traffic from the internet to work with Container Registry and Yandex Managed Service for GitLab."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 22
    to_port           = 5050
  }
  # Outgoing traffic.
  egress {
    protocol          = "ANY"
    description       = "The rule allows all outgoing traffic. Nodes can connect to Container Registry, Managed Service for GitLab to name but a few."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 0
    to_port           = 65535
  }
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name       = "k8s-cluster"
  network_id = yandex_vpc_network.my-net-for-gitlab.id
  master {
    version = local.k8s_version
    master_location {
      zone      = yandex_vpc_subnet.my-subnet-for-gitlab.zone
      subnet_id = yandex_vpc_subnet.my-subnet-for-gitlab.id
    }
    public_ip = true
    security_group_ids = [yandex_vpc_security_group.gitlab-security-group.id]
  }
  service_account_id      = yandex_iam_service_account.my-account-for-gitlab.id
  node_service_account_id = yandex_iam_service_account.my-account-for-gitlab.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.editor,
    yandex_resourcemanager_folder_iam_member.images-pusher,
    yandex_resourcemanager_folder_iam_member.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s-ng" {
  name       = "k8s-ng"
  cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  version    = local.k8s_version
  instance_template {
    name = "test-{instance.short_id}-{instance_group.id}"
    container_runtime {
      type = "docker"
    }
    platform_id = "standard-v2" # Intel Cascade Lake.
    resources {
      cores         = 2 # Number of CPU cores.
      core_fraction = 50 # %
      memory        = 2 # GB
    }
    boot_disk {
      size = 64 # GB
      type = "network-ssd"
    }
    network_acceleration_type = "standard"
    network_interface {
      security_group_ids = [yandex_vpc_security_group.gitlab-security-group.id]
      subnet_ids         = [yandex_vpc_subnet.my-subnet-for-gitlab.id]
      nat                = true
    }
  }
  scale_policy {
    fixed_scale {
      size = 1 # The number of nodes is fixed and equal to 1.
    }
  }
  allocation_policy {
    location {
      zone = yandex_vpc_subnet.my-subnet-for-gitlab.zone
    }
  }
  deploy_policy {
    max_expansion   = 4 # The number of nodes that Managed Service for Kubernetes can create when updating the node group.
    max_unavailable = 0 # The number of nodes that Managed Service for Kubernetes can delete when updating the node group.
  }
  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
    maintenance_window {
      start_time = "22:00"
      duration   = "10h"
    }
  }
}

resource "yandex_iam_service_account" "my-account-for-gitlab" {
  name = "my-account-for-gitlab"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  # The editor role is assigned to the service account.
  folder_id = local.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.my-account-for-gitlab.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-pusher" {
  # The container-registry.images.pusher role is assigned to the service account.
  folder_id = local.folder_id
  role      = "container-registry.images.pusher"
  member    = "serviceAccount:${yandex_iam_service_account.my-account-for-gitlab.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # The container-registry.images.puller role is assigned to the service account.
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.my-account-for-gitlab.id}"
}

resource "yandex_container_registry" "my-registry" {
  name = "my-registry"
}
