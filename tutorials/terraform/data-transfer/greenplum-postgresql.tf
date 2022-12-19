# Infrastructure for Yandex Cloud Managed Service for Greenplum® cluster, Yandex Cloud Managed Service for PostgreSQL, and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/greenplum-to-postgresql
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/greenplum-to-postgresql

# Specify the following settings
locals {
  gp_password = "" # Set a password for the Greenplum® admin user
  pg_password = "" # Set a password for the PostgreSQL admin user

  # Specify these settings ONLY AFTER the clusters are created. Then run "terraform apply" command again
  # You should set up the source endpoint using the GUI to obtain its ID
  gp_source_endpoint_id = "" # Set the source endpoint ID
  transfer_enabled      = 0  # Value '0' disables creating of transfer before the source endpoint is created manually. After that, set to '1' to enable transfer
}

resource "yandex_vpc_network" "mgp_network" {
  description = "Network for Managed Service for Greenplum®"
  name        = "mgp_network"
}

resource "yandex_vpc_network" "mpg_network" {
  description = "Network for Managed Service for PostgreSQL"
  name        = "mpg_network"
}

resource "yandex_vpc_subnet" "mgp_subnet-a" {
  description    = "Subnet in ru-central1-a availability zone for Greenplum®"
  name           = "mgp_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mgp_network.id
  v4_cidr_blocks = ["10.128.0.0/18"]
}

resource "yandex_vpc_subnet" "mpg_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for PostgreSQL"
  name           = "mpg_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mpg_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mgp_security_group" {
  network_id  = yandex_vpc_network.mgp_network.id
  name        = "Managed Greenplum® security group"
  description = "Security group for Managed Service for Greenplum®"

  ingress {
    description    = "Allow incoming traffic from members of the same security group"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to members of the same security group"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mpg_security_group" {
  network_id  = yandex_vpc_network.mpg_network.id
  name        = "Managed PostgreSQL security group"
  description = "Security group for Managed Service for PostgreSQL"

  ingress {
    description    = "Allow incoming traffic from the port 6432"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing traffic to members of the same security group"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_greenplum_cluster" "mgp-cluster" {
  description        = "Managed Greenplum® cluster"
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
      resource_preset_id = "s3-c8-m32" # 8 vCPU, 32 GB RAM
      disk_size          = 100         # GB
      disk_type_id       = "network-ssd"
    }
  }
  segment_subcluster {
    resources {
      resource_preset_id = "s3-c8-m32" # 8 vCPU, 32 GB RAM
      disk_size          = 93          # GB
      disk_type_id       = "network-ssd-nonreplicated"
    }
  }

  user_name     = "gp-user"
  user_password = local.gp_password

  security_group_ids = [yandex_vpc_security_group.mgp_security_group.id]
}

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed PostgreSQL cluster"
  name               = "mpg-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mpg_network.id
  security_group_ids = [yandex_vpc_security_group.mpg_security_group.id]

  config {
    version = 14
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = "20"
    }
  }

  database {
    name  = "db1"
    owner = "pg-user"
  }

  user {
    name     = "pg-user"
    password = local.pg_password
    permission {
      database_name = "db1"
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mpg_subnet-a.id
    assign_public_ip = true
  }
}

resource "yandex_datatransfer_endpoint" "pg_target" {
  description = "Target endpoint for PostgreSQL cluster"
  name        = "pg-target-tf"
  settings {
    postgres_target {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = "db1"
      user     = "pg-user"
      password {
        raw = local.pg_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mgp-mpg-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for Greenplum® to the Managed Service for PostgreSQL"
  name        = "mgp-mpg-transfer"
  source_id   = local.gp_source_endpoint_id
  target_id   = yandex_datatransfer_endpoint.pg_target.id
  type        = "SNAPSHOT_ONLY" # Copying data from the source Managed Service for Greenplum® database.
}
