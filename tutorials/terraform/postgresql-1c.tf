# Infrastructure for Yandex Cloud Managed Service for PostgreSQL 1C cluster
#
# RU: https://cloud.yandex.ru/docs/managed-postgresql/tutorials/1c-postgresql
# EN: https://cloud.yandex.com/en/docs/managed-postgresql/tutorials/1c-postgresql
#
# Set the following settings:

locals {
  db_password = "" # Set database user password
}


resource "yandex_vpc_network" "postgresql-1c-network" {
  description = "Network for the Managed Service for PostgreSQL 1C cluster"
  name        = "postgresql-1c-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "postgresql-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.postgresql-1c-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-b" {
  description    = "Subnet in the ru-central1-b availability zone"
  name           = "postgresql-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.postgresql-1c-network.id
  v4_cidr_blocks = ["10.2.0.0/16"]
}

resource "yandex_vpc_subnet" "subnet-c" {
  description    = "Subnet in the ru-central1-c availability zone"
  name           = "postgresql-subnet-c"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.postgresql-1c-network.id
  v4_cidr_blocks = ["10.3.0.0/16"]
}

resource "yandex_vpc_default_security_group" "postgresql-security-group" {
  description = "Security group for the Managed Service for PostgreSQL 1C cluster"
  network_id  = yandex_vpc_network.postgresql-1c-network.id

  ingress {
    description    = "Allow incoming connections to cluster from the Internet"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_postgresql_database" "postgresql-1c" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-1c.id
  name       = "postgresql-1c"
  owner      = yandex_mdb_postgresql_user.user.name # Base owner name
}

resource "yandex_mdb_postgresql_user" "user" {
  cluster_id = yandex_mdb_postgresql_cluster.postgresql-1c.id
  name       = "user-1c" # Username
  password   = local.db_password

}

resource "yandex_mdb_postgresql_cluster" "postgresql-1c" {
  description        = "Managed Service for PostgreSQL 1C cluster"
  name               = "postgresql-1c"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.postgresql-1c-network.id
  security_group_ids = [yandex_vpc_default_security_group.postgresql-security-group.id]

  config {
    version = "12-1c"
    resources {
      resource_preset_id = "s2.small"
      disk_type_id       = "network-ssd"
      disk_size          = "10" # GB
    }
  }
  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  host {
    zone             = "ru-central1-b"
    subnet_id        = yandex_vpc_subnet.subnet-b.id
    assign_public_ip = true # Required for connection from the Internet
  }

  host {
    zone             = "ru-central1-c"
    subnet_id        = yandex_vpc_subnet.subnet-c.id
    assign_public_ip = true # Required for connection from the Internet
  }
}
