# Infrastructure for the Yandex Cloud Managed Service for Apache Kafka® and ClickHouse clusters
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/fetch-data-from-mkf
#
# Set the configuration of the Managed Service for Apache Kafka® and ClickHouse clusters.

# Specify the following settings:

locals {
  # Settings for Managed Service for Apache Kafka® cluster:
  producer_name     = "" # Name of a user with the producer role
  producer_password = "" # Password of the user with the producer role
  topic_name        = "" # Apache Kafka® topic name. Each Managed Service for Apache Kafka® cluster must have its unique topic name.
  consumer_name     = "" # Name of a user with the consumer role
  consumer_password = "" # Password of the user with the consumer role

  # Settings for Managed Service for ClickHouse cluster:
  db_user_name      = "" # Name of the ClickHouse database user
  db_user_password  = "" # Password of the ClickHouse database user

  # The following settings are predefined. Change them only if necessary.

  zone_a_v4_cidr_blocks   = "10.1.0.0/16"        # CIDR block for subnet in the ru-central1-a availability zone
  kafka_cluster_name      = "kafka-cluster"      # Managed Service for Apache Kafka® cluster name. If you are going to create multiple clusters, then duplicate, rename, and edit this variable.
  clickhouse_cluster_name = "clickhouse-cluster" # Managed Service for ClickHouse cluster name
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for Apache Kafka® and ClickHouse clusters"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}


resource "yandex_vpc_default_security_group" "security-group" {
  description = "Security group for the Managed Service for Apache Kafka® and ClickHouse clusters"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allows connections to the Managed Service for Apache Kafka® cluster from the Internet."
    protocol       = "TCP"
    port           = 9091
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allows connections to the Managed Service for ClickHouse cluster from the Internet."
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allows outgoing connections to any required resource."
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_mdb_kafka_cluster" "kafka-cluster" {
  description        = "Managed Service for Apache Kafka® cluster"
  name               = local.kafka_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  config {
    assign_public_ip = true
    brokers_count    = 1
    version          = "2.8"
    zones            = ["ru-central1-a"]
    kafka {
      resources {
        resource_preset_id = "s2.micro"
        disk_type_id       = "network-hdd"
        disk_size          = 10 # GB
      }
    }
  }

  user {
    name     = local.producer_name
    password = local.producer_password
    permission {
      topic_name = local.topic_name
      role       = "ACCESS_ROLE_PRODUCER"
    }
  }

  user {
    name     = local.consumer_name
    password = local.consumer_password
    permission {
      topic_name = local.topic_name
      role       = "ACCESS_ROLE_CONSUMER"
    }
  }
}

resource "yandex_mdb_kafka_topic" "events" {
  cluster_id         = yandex_mdb_kafka_cluster.kafka-cluster.id
  name               = local.topic_name
  partitions         = 4
  replication_factor = 1
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = local.clickhouse_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }

    # Uncomment the next block if you are going to use only one Managed Service for Apache Kafka® cluster.

    #config {
    #  kafka {
    #    security_protocol = "SECURITY_PROTOCOL_SASL_SSL"
    #    sasl_mechanism    = "SASL_MECHANISM_SCRAM_SHA_512"
    #    sasl_username     = local.consumer_name
    #    sasl_password     = local.consumer_password
    #  }
    #}

    # Uncomment the next block if you are going to use multiple Managed Service for Apache Kafka® clusters. Specify topic name and consumer credentials.

    #config {
    #  kafka_topic {
    #    name = "<topic name>"
    #    settings {
    #    security_protocol = "SECURITY_PROTOCOL_SASL_SSL"
    #    sasl_mechanism    = "SASL_MECHANISM_SCRAM_SHA_512"
    #    sasl_username     = "<name of the user for the consumer>"
    #    sasl_password     = "<password of the user for the consumer>"
    #    }
    #  }
    #}

  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = "db1"
  }

  user {
    name     = local.db_user_name
    password = local.db_user_password
    permission {
      database_name = "db1"
    }
  }
}
