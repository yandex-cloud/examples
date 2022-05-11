# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster with advanced sharding: one shard in the first group, two shards in the second one
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/sharding
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/sharding
#
# Set the user name and password for Managed Service for ClickHouse cluster


# Network
resource "yandex_vpc_network" "clickhouse_sharding_network" {
  name        = "clickhouse_sharding_network"
  description = "Network for Managed Service for ClickHouse cluster with sharding."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "clickhouse-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

# Subnet in ru-central1-b availability zone
resource "yandex_vpc_subnet" "subnet-b" {
  name           = "clickhouse-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = ["10.2.0.0/24"]
}

# Subnet in ru-central1-c availability zone
resource "yandex_vpc_subnet" "subnet-c" {
  name           = "clickhouse-subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = ["10.3.0.0/24"]
}

# Security group for Managed Service for ClickHouse cluster
resource "yandex_vpc_default_security_group" "clickhouse-security-group" {
  network_id = yandex_vpc_network.clickhouse_sharding_network.id

  # Allow connections to cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow incoming SSL-connections with clickhouse-client from Internet"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow connections from cluster to any required resource
  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for ClickHouse cluster with advanced sharding
resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster-sharded" {
  name               = "clickhouse-cluster-sharded"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.clickhouse_sharding_network.id
  security_group_ids = [yandex_vpc_default_security_group.clickhouse-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 16 # GB
    }
  }

  zookeeper {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = "shard1"
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.subnet-b.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = "shard2"
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-c"
    subnet_id        = yandex_vpc_subnet.subnet-c.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = "shard3"
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-a.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.subnet-b.id
  }

  host {
    type      = "ZOOKEEPER"
    zone      = "ru-central1-c"
    subnet_id = yandex_vpc_subnet.subnet-c.id
  }

  shard_group {
    name        = "sgroup"
    description = "Shard group with two shards"
    shard_names = [
      "shard1",
      "shard2"
    ]
  }

  shard_group {
    name        = "sgroup_data"
    description = "Shard group with one shard"
    shard_names = [
      "shard3"
    ]
  }

  database {
    name = "tutorial"
  }

  user {
    name     = "" # Set username
    password = "" # Set user password
    permission {
      database_name = "tutorial"
    }
  }
}
