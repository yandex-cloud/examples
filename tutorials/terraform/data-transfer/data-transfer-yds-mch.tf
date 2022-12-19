# Infrastructure for the Yandex Cloud Data Streams, Managed Service for ClickHouse cluster, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/yds-to-clickhouse
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/yds-to-clickhouse
#
# Set source cluster and target database settings.
locals {
  folder_id = "" # Your Folder ID.
  sa_name   = "" # Set a service account name. It must be unique in the folder.

  # Source database settings:
  source_db_name = "" # Set the source YDB database name.

  # Target cluster settings:
  target_db_name  = "" # Set the target ClickHouse database name
  target_user     = "" # Set the user name for Managed Service for ClickHouse cluster
  target_password = "" # Set the user password for Managed Service for ClickHouse cluster

  # Specify these settings ONLY AFTER the cluster and YDB database are created. Then run "terraform apply" command again.
  # You should set up the source endpoint using the GUI to obtain its ID.
  source_endpoint_id = "" # Set the source endpoint id.
  transfer_enabled   = 0  # Value '0' disables creating of transfer before the source endpoint is created manually. After that, set to '1' to enable transfer.
}

resource "yandex_iam_service_account" "sa-yds-obj" {
  description = "Service account for migration from the Data Streams to Managed Service for ClickHouse cluster"
  name        = local.sa_name
}

# Assign role `editor` to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

resource "yandex_ydb_database_serverless" "ydb" {
  name = local.source_db_name
}

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for ClickHouse cluster"
  name        = "network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "Allow connections with clickhouse-client to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTP connections to the Managed Service for ClickHouse cluster from the Internet"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "The rule allows all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = local.target_db_name
  }

  user {
    name     = local.target_user
    password = local.target_password
    permission {
      database_name = local.target_db_name
    }
  }
}

resource "yandex_datatransfer_endpoint" "mch-target" {
  description = "Target endpoint for ClickHouse cluster"
  name        = "mch-target"
  settings {
    clickhouse_target {
      connection {
        connection_options {
          mdb_cluster_id = yandex_mdb_clickhouse_cluster.clickhouse-cluster.id
          database       = local.target_db_name
          user           = local.target_user
          password {
            raw = local.target_password
          }
        }
      }
      cleanup_policy = "CLICKHOUSE_CLEANUP_POLICY_DROP"
    }
  }
}

resource "yandex_datatransfer_transfer" "yds-mch-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Data Streams to the Managed Service for ClickHouse cluster"
  name        = "transfer-from-yds-to-mch"
  source_id   = local.source_endpoint_id
  target_id   = yandex_datatransfer_endpoint.mch-target.id
  type        = "INCREMENT_ONLY" # Replication data from the source Data Stream.
}
