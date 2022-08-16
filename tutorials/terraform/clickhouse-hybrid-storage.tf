# Infrastructure for the Yandex Cloud Managed Service for ClickHouse cluster with hybrid storage
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage
#
# Set the following settings:

locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  db_username           = ""            # Set database username.
  db_password           = ""            # Set database user password.
  db_name               = "tutorial"    # Set database name.
}

resource "yandex_vpc_network" "clickhouse_hybrid_storage_network" {
  description = "Network for the Managed Service for ClickHouse cluster with hybrid storage"
  name        = "clickhouse-hybrid-storage-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "clickhouse-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse_hybrid_storage_network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_default_security_group" "clickhouse-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.clickhouse_hybrid_storage_network.id

  ingress {
    description    = "Allow incoming connections to cluster from Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster with enabled hybrid storage"
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
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from Internet.
  }

  database {
    name = local.db_name
  }

  user {
    name     = local.db_username
    password = local.db_password
    permission {
      database_name = local.db_name
    }
  }

  # Enable hybrid storage
  cloud_storage {
    enabled = true
  }
}
