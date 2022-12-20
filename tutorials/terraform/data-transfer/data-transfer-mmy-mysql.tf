# Configure source and target clusters
locals {
  # Source cluster settings
  mdb-cluster-id = "" # Set the Managed Service for MySQL cluster ID.
  source-user    = "" # Set the source cluster username.
  source-db      = "" # Set the source cluster database name.
  source-pwd     = "" # Set the source cluster password.
  # Target cluster settings
  target-user = ""   # Set the target cluster username.
  target-db   = ""   # Set the target cluster database name.
  target-pwd  = ""   # Set the target cluster password.
  target-host = ""   # Set the target cluster master host IP address or FQDN.
  target-port = 3306 # Set the target cluster port number that Data Transfer will use for connections.
}

resource "yandex_datatransfer_endpoint" "managed-mysql-source" {
  description = "Source endpoint for Managed Service for MySQL cluster"
  name        = "managed-mysql-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = local.mdb-cluster-id
      }
      database = local.source-db
      user     = local.source-user
      password {
        raw = local.source-pwd
      }
    }
  }
}

resource "yandex_datatransfer_endpoint" "mysql-target" {
  description = "Target endpoint for MySQL cluster"
  name        = "mysql-target"
  settings {
    mysql_target {
      connection {
        on_premise {
          hosts = [local.target-host]
          port  = local.target-port
        }
      }
      database = local.target-db
      user     = local.target-user
      password {
        raw = local.target-pwd
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mysql-transfer" {
  description = "Transfer from Managed for MySQL cluster to MySQL cluster"
  name        = "transfer-from-managed-mysql-to-onpremise-mysql"
  source_id   = yandex_datatransfer_endpoint.managed-mysql-source.id
  target_id   = yandex_datatransfer_endpoint.mysql-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication
}
