# Infrastructure for Yandex Cloud Managed Service for PostgreSQL cluster and Yandex Cloud Managed Service for Apache Kafka®
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/mkf-to-mpg
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/mkf-to-mpg

# Specify the following settings
locals {
  pg_version = "" # Set a desired version of PostgreSQL. For available versions, see the documentation main page : https://cloud.yandex.com/en/docs/managed-postgresql/
  kf_version = "" # Set a desired version of Apache Kafka®. For available versions, see the documentation main page : https://cloud.yandex.com/en/docs/managed-kafka/
  pg_password = "" # Set a password for the PostgreSQL admin user
  kf_password = "" # Set a password for the Apache Kafka® user

  # Specify these settings ONLY AFTER the clusters are created. Then run "terraform apply" command again
  # You should set up endpoints using the GUI to obtain their IDs
  kf_source_endpoint_id = "" # Set the source endpoint ID
  transfer_enabled      = 0                      # Set to 1 to enable transfer
}

resource "yandex_vpc_network" "mpg_network" {
  description = "Network for Managed Service for PostgreSQL"
  name        = "mpg_network"
}

resource "yandex_vpc_network" "mkf_network" {
  description = "Network for Managed Service for Apache Kafka®"
  name        = "mkf_network"
}

resource "yandex_vpc_subnet" "mpg_subnet-a" {
  description    = "Subnet in ru-central1-a availability zone for PostgreSQL"
  name           = "mpg_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mpg_network.id
  v4_cidr_blocks = ["10.128.0.0/18"]
}

resource "yandex_vpc_subnet" "mkf_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for Apache Kafka®"
  name           = "mkf_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mkf_network.id
  v4_cidr_blocks = ["10.129.0.0/24"]
}

resource "yandex_vpc_security_group" "mpg_security_group" {
  description = "Security group for Managed Service for PostgreSQL"
  network_id  = yandex_vpc_network.mpg_network.id
  name        = "Managed PostgreSQL security group"

  ingress {
    description    = "Allow incoming traffic from the Internet"
    protocol       = "TCP"
    port      = 6432
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

resource "yandex_vpc_security_group" "mkf_security_group" {
  description = "Security group for Managed Service for Apache Kafka®"
  network_id  = yandex_vpc_network.mkf_network.id
  name        = "Managed Apache Kafka® security group"

  ingress {
    description    = "Allow incoming traffic from the port 9091"
    protocol       = "TCP"
    port           = 9091
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

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = "mpg-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.mpg_network.id
  security_group_ids = [yandex_vpc_security_group.mpg_security_group.id]

  config {
    version = local.pg_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = "20" # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.mpg_subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}

resource "yandex_mdb_postgresql_user" "pg-user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = "pg-user"
  password   = local.pg_password
}

resource "yandex_mdb_postgresql_database" "mpg-db" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = "db1"
  owner      = yandex_mdb_postgresql_user.pg-user.name
  depends_on = [
    yandex_mdb_postgresql_user.pg-user
  ]
}

resource "yandex_mdb_kafka_cluster" "mkf-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
  environment        = "PRODUCTION"
  name               = "mkf-cluster"
  network_id         = yandex_vpc_network.mkf_network.id
  security_group_ids = [yandex_vpc_security_group.mkf_security_group.id]

  config {
    assign_public_ip = true # Required for connection from the Internet
    brokers_count    = 1
    version          = local.kf_version
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro"
      }
    }

    zones = ["ru-central1-a"]
  }

  user {
    name     = "mkf-user"
    password = local.kf_password
    permission {
      topic_name = "sensors"
      role       = "ACCESS_ROLE_CONSUMER"
    }
    permission {
      topic_name = "sensors"
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }
}

# Managed Service for Apache Kafka® topic
resource "yandex_mdb_kafka_topic" "sensors" {
  cluster_id         = yandex_mdb_kafka_cluster.mkf-cluster.id
  name               = "sensors"
  partitions         = 1
  replication_factor = 1
}

resource "yandex_datatransfer_endpoint" "pg_target" {
  count       = local.transfer_enabled
  description = "Target endpoint for PostgreSQL cluster"
  name = "pg-target-tf"
  settings {
    postgres_target {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = yandex_mdb_postgresql_database.mpg-db.name
      user = yandex_mdb_postgresql_user.pg-user.name
      password {
        raw = local.pg_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mkf-mpg-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Managed Service for Apache Kafka® to the Managed Service for PostgreSQL"
  name        = "mkf-mpg-transfer"
  source_id   = local.kf_source_endpoint_id
  target_id   = yandex_datatransfer_endpoint.pg_target[count.index].id
  type        = "INCREMENT_ONLY" # Data replication from the source Managed Service for Apache Kafka® topic to the target Managed Service for PostgreSQL cluster
}
