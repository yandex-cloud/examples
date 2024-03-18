# Infrastructure for the Managed Service for OpenSearch cluster and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/os-to-mos
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/os-to-mos
#
# Specify the following settings:
locals {
  # Source Managed Service for OpenSearch cluster settings:
  os_admin_password = "" # Set a password for the OpenSearch admin user.

  # Specify these settings ONLY AFTER the clusters are created. Then run the "terraform apply" command again.
  # You should set up endpoints using the GUI to obtain their IDs.
  source_endpoint_id = "" # Set the source endpoint ID.
  target_endpoint_id = "" # Set the target endpoint ID.
  transfer_enabled   = 0  # Set to 1 to enable the transfer.

  # The following settings are predefined. Change them only if necessary.
  network_name          = "mos-network"        # Name of the network
  subnet_name           = "mos-subnet-a"       # Name of the subnet
  zone_a_v4_cidr_blocks = "10.1.0.0/16"        # CIDR block for the subnet in the ru-central1-a availability zone
  security_group_name   = "mos-security-group" # Name of the security group
  mos_cluster_name      = "mos-cluster"        # Name of the OpenSearch cluster
  source_endpoint_name  = "os-source"          # Name of the source endpoint for the OpenSearch cluster
  target_endpoint_name  = "mos-target"         # Name of the target endpoint for the Managed Service for OpenSearch cluster
  transfer_name         = "os-mos-transfer"    # Name of the transfer from a standalone OpenSearch cluster to the Managed Service for OpenSearch
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for OpenSearch clusters"
  name        = local.network_name
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for OpenSearch clusters"
  name        = local.security_group_name
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "The rule allows connections to the Managed Service for OpenSearch clusters from the internet"
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "The rule allows connections to the Managed Service for OpenSearch clusters from the internet"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "The rule allows all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_mdb_opensearch_cluster" "opensearch" {
  name               = local.mos_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  config {
    admin_password = local.os_admin_password

    opensearch {
      node_groups {
        name             = "group0"
        assign_public_ip = true
        hosts_count      = 1
        subnet_ids       = [yandex_vpc_subnet.subnet-a.id]
        zone_ids         = ["ru-central1-a"]
        roles            = ["data", "manager"]
        resources {
          resource_preset_id = "s2.micro"
          disk_size          = 10737418240 # 10 GB
          disk_type_id       = "network-ssd"
        }
      }
    }

    dashboards {
      node_groups {
        name             = "dashboards"
        assign_public_ip = true
        hosts_count      = 1
        zone_ids         = ["ru-central1-a"]
        resources {
          resource_preset_id = "s2.micro"
          disk_size          = 10737418240 # 10 GB
          disk_type_id       = "network-ssd"
        }
      }
    }
  }

  maintenance_window {
    type = "ANYTIME"
  }
}

resource "yandex_datatransfer_transfer" "os-mos-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from a standalone OpenSearch cluster to the Managed Service for OpenSearch cluster"
  name        = local.transfer_name
  source_id   = local.source_endpoint_id
  target_id   = local.target_endpoint_id
  type        = "SNAPSHOT_ONLY" # Copy data
}
