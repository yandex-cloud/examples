# Infrastructure for Yandex Cloud Managed Service for ClickHouse cluster with simple sharding: one shard for every host
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/sharding
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/sharding
#
# Set the following settings:

locals {
  db_username              = ""            # Set database username.
  db_password              = ""            # Set database user password.
  db_name                  = "tutorial"    # Set database name.
  zone_a_v4_cidr_blocks    = "10.1.0.0/24" # Set the CIDR block for subnet in the ru-central1-a availability zone.
  zone_b_v4_cidr_blocks    = "10.2.0.0/24" # Set the CIDR block for subnet in the ru-central1-b availability zone.
  zone_c_v4_cidr_blocks    = "10.3.0.0/24" # Set the CIDR block for subnet in the ru-central1-c availability zone.
  cluster_name             = "chcluster"   # Set the Managed Service for ClickHouse cluster name
  mch_master_host_class    = "s2.micro"    # Set the host class for the Managed Service for ClickHouse cluster master host.
  mch_zk_host_class        = "s2.micro"    # Set the host class for the Managed Service for ClickHouse cluster Zookeeper host.
  shard_group_2shards_name = "sgroup"      # Set the shard group with two shards name
  shard_group_data_name    = "sgroup_data" # Set the shard group with one shard name
  shard_name1              = "shard1"      # Set the name for the first shard.
  shard_name2              = "shard2"      # Set the name for the first shard.
  shard_name3              = "shard3"      # Set the name for the first shard.
}

resource "yandex_vpc_network" "clickhouse_sharding_network" {
  description = "Network for the Managed Service for ClickHouse cluster with sharding"
  name        = "clickhouse_sharding_network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "clickhouse-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_subnet" "subnet-b" {
  description    = "Subnet in the ru-central1-b availability zone"
  name           = "clickhouse-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = [local.zone_b_v4_cidr_blocks]
}

resource "yandex_vpc_subnet" "subnet-c" {
  description    = "Subnet in the ru-central1-c availability zone"
  name           = "clickhouse-subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.clickhouse_sharding_network.id
  v4_cidr_blocks = [local.zone_c_v4_cidr_blocks]
}

resource "yandex_vpc_default_security_group" "clickhouse-security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.clickhouse_sharding_network.id

  ingress {
    description    = "Allow incoming SSL-connections with clickhouse-client from Internet"
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

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster-sharded" {
  description        = "Managed Service for ClickHouse cluster with simple sharding"
  name               = local.cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.clickhouse_sharding_network.id
  security_group_ids = [yandex_vpc_default_security_group.clickhouse-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = local.mch_master_host_class
      disk_type_id       = "network-ssd"
      disk_size          = 16 # GB
    }
  }

  zookeeper {
    resources {
      resource_preset_id = local.mch_zk_host_class
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = local.shard_name1
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.subnet-b.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = local.shard_name2
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-c"
    subnet_id        = yandex_vpc_subnet.subnet-c.id
    assign_public_ip = true # Required for connection from the Internet
    shard_name       = local.shard_name3
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
}
