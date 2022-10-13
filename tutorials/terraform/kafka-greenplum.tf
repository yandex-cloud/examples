# Infrastructure for Yandex Cloud Managed Service for Greenplum® cluster and Yandex Cloud Managed Service for Apache Kafka®
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/managed-kafka-to-greenplum
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/managed-kafka-to-greenplum

# Specify the following settings
locals {
  gp_password = "" # Set a password for the Greenplum® admin user
  kf_password = "" # Set a password for the Apache Kafka® user
}

resource "yandex_vpc_network" "mgp_network" {
  description = "Network for Managed Service for Greenplum®"
  name        = "mgp_network"
}

resource "yandex_vpc_network" "mkf_network" {
  description = "Network for Managed Service for Apache Kafka®"
  name        = "mkf_network"
}

resource "yandex_vpc_subnet" "mgp_subnet-a" {
  description    = "Subnet in ru-central1-a availability zone for Greenplum®"
  name           = "mgp_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mgp_network.id
  v4_cidr_blocks = ["10.128.0.0/18"]
}

resource "yandex_vpc_subnet" "mkf_subnet-a" {
  description    = "Subnet ru-central1-a availability zone for Apache Kafka®"
  name           = "mkf_subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mkf_network.id
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

resource "yandex_mdb_kafka_cluster" "mkf-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
  environment        = "PRODUCTION"
  name               = "mkf-cluster"
  network_id         = yandex_vpc_network.mkf_network.id
  security_group_ids = [yandex_vpc_security_group.mkf_security_group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = "2.8"
    kafka {
      resources {
        disk_size          = 10 # GB
        disk_type_id       = "network-ssd"
        resource_preset_id = "s2.micro"
      }
    }

    zones = [
      "ru-central1-a"
    ]
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
