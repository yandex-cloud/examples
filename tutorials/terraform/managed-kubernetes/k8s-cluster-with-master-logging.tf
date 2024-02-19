# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster
#
# RU: https://cloud.yandex.ru/docs/logging/tutorials/k8s-fluent-bit-logging
# EN: https://cloud.yandex.com/en/docs/logging/tutorials/k8s-fluent-bit-logging

# Set the configuration of Managed Service for Kubernetes cluster:
locals {
  folder_id      = "" # Your cloud folder ID, same as for provider
  k8s_version    = "" # Desired version of Kubernetes. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-kubernetes/concepts/release-channels-and-updates.
  sa_name        = "" # Service account name. It must be unique in a cloud.
  log_group_name = "" # Loging group name

  # The following settings are predefined. Change them only if necessary.
  network_name             = "k8s-network"         # Name of the network
  subnet_name              = "subnet-a"            # Name of the subnet
  zone_a_v4_cidr_blocks    = "10.1.0.0/16"         # CIDR block for the subnet in the ru-central1-a availability zone
  main_security_group_name = "k8s-main-sg"         # Name of the main security group of the cluster
  public_services_sg_name  = "k8s-public-services" # Name of the public services security group for node groups
  k8s_cluster_name         = "k8s-cluster"         # Name of the Kubernetes cluster
  k8s_node_group_name      = "k8s-node-group"      # Name of the Kubernetes node group
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = local.network_name
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "The security group ensures the basic performance of the cluster. Apply it to the cluster and node groups."
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
    description    = "The rule allows the pod-pod and service-service interaction"
    protocol       = "ANY"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    description    = "The rule allows receiving debug ICMP packets from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on port 6443 from the specified network"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    description    = "The rule allows connection to Kubernetes API on port 443 from the specified network"
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
  description = "The security group allows connections to services from the internet. Apply the rules only for your node groups."
  name        = local.public_services_sg_name
  network_id  = yandex_vpc_network.k8s-network.id

  ingress {
    description    = "The rule allows incoming traffic from the internet to the NodePort port range"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Kubernetes cluster"
  name        = local.sa_name
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

# Assign role "logging.writer" to the Kubernetes service account
resource "yandex_resourcemanager_folder_iam_binding" "logging-writer" {
  folder_id = local.folder_id
  role      = "logging.writer"
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
    master_location {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]

    master_logging {
      enabled                    = true
      log_group_id               = yandex_logging_group.logging-group.id
      kube_apiserver_enabled     = true
      cluster_autoscaler_enabled = true
      events_enabled             = true
      audit_enabled              = true
    }

  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # ID of the service account for the cluster
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # ID of the service account for the node group
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller,
    yandex_resourcemanager_folder_iam_binding.logging-writer,
    yandex_logging_group.logging-group
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for the Managed Service for Kubernetes cluster"
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
      subnet_ids         = [yandex_vpc_subnet.subnet-a.id]
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

resource "yandex_logging_group" "logging-group" {
  description = "Cloud Logging group"
  name        = local.log_group_name
  folder_id   = local.folder_id
}
