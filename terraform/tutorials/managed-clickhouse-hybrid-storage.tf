# Infrastructure for Yandex.Cloud Managed Service for ClickHouse cluster with hybrid storage
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage
#
# Set the user name and password for Managed Service for ClickHouse cluster


# Network
resource "yandex_vpc_network" "clickhouse_hybrid_storage_network" {
  name        = "clickHouse_hybrid_storage_network"
  description = "Network for Managed Service for ClickHouse cluster with hybrid storage."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet_zone_a" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse_hybrid_storage_network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for Managed Service for ClickHouse cluster
resource "yandex_vpc_default_security_group" "clickhouse-security-group" {
  name = "clickhouse-security-group"

  # Allow connections to cluster from internet
  ingress {
    protocol       = "TCP"
    description    = "Allow incoming SSL-connections with clickhouse-client from Internet"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connections from cluster to Yandex Object Storage
  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for ClickHouse cluster with hybrid storage
resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.clickhouse_hybrid_storage_network.id
  security_group_ids = [yandex_vpc_default_security_group.clickhouse-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 32 # GB
    }
  }

  host {
    type      = "CLICKHOUSE"
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subneb.subnet-a.id
  }

  database {
    name = "tutorial"
  }

  user {
    name     = "" # Set the user name
    password = "" # Set the user password
    permission {
      database_name = "tutorials"
    }
  }

  cloud_storage = true # Allow use hybrid storage
}
