# Infrastructure for Yandex Cloud Managed Service for Greenplum® cluster and Yandex Cloud Managed Service for ClickHouse
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/greenplum-to-clickhouse
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/greenplum-to-clickhouse

# Specify the following settings
locals {
  gp_password = "" # Set a password for the Greenplum® admin user
  ch_password = "" # Set a password for the ClickHouse admin user
}

resource "yandex_vpc_network" "mgp_network" {
  description = "Network for Managed Service for Greenplum®"
  name        = "mgp_network"
}

resource "yandex_vpc_network" "mch_network" {
  description = "Network for Managed Service for ClickHouse"
  name        = "mch_network"
}

resource "yandex_vpc_subnet" "mgp_subnet-a" {
  description    = "Subnet in ru-central1-a availability zone for Greenplum®"
  name           = "mgp_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mgp_network.id
  v4_cidr_blocks = ["10.128.0.0/18"]
}

resource "yandex_vpc_subnet" "mch_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for ClickHouse"
  name           = "mch_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mch_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mgp_security_group" {
  description = "Security group for Managed Service for Greenplum®"
  network_id  = yandex_vpc_network.mgp_network.id
  name        = "Managed Greenplum® security group"

  ingress {
    description    = "Allow incoming traffic from the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mch_security_group" {
  description = "Security group for Managed Service for ClickHouse"
  network_id  = yandex_vpc_network.mch_network.id
  name        = "Managed ClickHouse security group"

  ingress {
    description    = "Allow incoming traffic from the port 8443"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow incoming traffic from the port 9440"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_greenplum_cluster" "mgp-cluster" {
  description        = "Managed Service for Greenplum® cluster"
  name               = "mgp-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mgp_network.id
  zone               = "ru-central1-a"
  subnet_id          = yandex_vpc_subnet.mgp_subnet-a.id
  assign_public_ip   = true
  version            = "6.19"
  master_host_count  = 2
  segment_host_count = 2
  segment_in_host    = 1
  master_subcluster {
    resources {
      resource_preset_id = "s2.medium" # 8 vCPU, 32 GB RAM
      disk_size          = 100         #GB
      disk_type_id       = "local-ssd"
    }
  }
  segment_subcluster {
    resources {
      resource_preset_id = "s2.medium" # 8 vCPU, 32 GB RAM
      disk_size          = 100         # GB
      disk_type_id       = "local-ssd"
    }
  }

  user_name     = "user"
  user_password = local.gp_password

  security_group_ids = [yandex_vpc_security_group.mgp_security_group.id]
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "mch-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mch_network.id
  security_group_ids = [yandex_vpc_security_group.mch_security_group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mch_subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = "db1"
  }

  user {
    name     = "user"
    password = local.ch_password
    permission {
      database_name = "db1"
    }
  }
}
