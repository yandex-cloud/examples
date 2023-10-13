# Infrastructure for the Amazon RDS for PostgreSQL, Managed Service for PostgreSQL, and Data Transfer
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/rds-to-mpg
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/rds-to-mpg
#
# Specify the following settings:

locals {
  # Settings for Amazon RDS for PostgreSQL instance:
  rds_pg_version       = ""       # Desired version of PostgreSQL. For available versions, see the documentation main page: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts.General.DBVersions.
  parameter_family     = ""       # Parameter group family. Consists of "postgres" and version of PostgreSQL, for example: "postgres15".
  rds_pg_user_password = ""       # User password
  aws_certificate      = file("") # Path to a certificate .pem file

  # Settings for Managed Service for PostgreSQL cluster:
  mpg_version       = "" # Desired version of PostgreSQL. For available versions, see the documentation main page: https://cloud.yandex.com/en/docs/managed-postgresql/.
  mpg_user_password = "" # User password

  # The following settings are predefined. Change them only if necessary.

  # AWS settings
  rds_identifier        = "demo-postgres"  # Name of the RDS instance
  rds_pg_port           = 5432             # RDS instance port
  parameter_family_name = "pg-replication" # Name of the RDS parameter family
  rds_instance_class    = "db.t3.micro"    # RDS instance class
  rds_db_name           = "demodb"         # Name of the RDS instance database
  rds_user              = "demouser"       # Name of the RDS instance user

  # Managed Service for PostgreSQL settings
  network_name          = "mpg-network"        # Name of the network
  subnet_name           = "mpg-subnet-a"       # Name of the subnet
  zone_a_v4_cidr_blocks = "10.1.0.0/16"        # CIDR block for the subnet in the ru-central1-a availability zone
  security_group_name   = "security-group"     # Name of the security group
  pg_cluster_name       = "postgresql-cluster" # Name of the PostgreSQL cluster
  pg_db_name            = "mpg-db"             # Name of the PostgreSQL cluster database
  pg_username           = "mpg-user"           # Name of the PostgreSQL username

  # Data Transfer settings
  source_endpoint_name = "rds_source"       # Name of the source endpoint for Amazon RDS instance
  target_endpoint_name = "mpg_target"       # Name of the target endpoint for PostgreSQL cluster
  transfer_name        = "rds-mpg-transfer" # Name of the transfer from the Amazon RDS PostgreSQL to the Managed Service for PostgreSQL

  # Change this setting ONLY AFTER the clusters are created. Then run "terraform apply" command again.
  transfer_enabled = 0 # Set to 1 to enable Transfer
}

# AWS infrastructure

# Data sources to get VPC, subnets and security group details

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

resource "aws_security_group_rule" "pg_rule" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = local.rds_pg_port
  to_port           = local.rds_pg_port
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.default.id
}

resource "aws_db_subnet_group" "subnet_group" {
  name        = local.rds_identifier
  description = "Database subnet group for AWS PG"
  subnet_ids  = data.aws_subnets.all.ids
}

# Parmeter group for AWS PG
resource "aws_db_parameter_group" "replication" {
  name   = local.parameter_family_name
  family = local.parameter_family

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.logical_replication"
    value        = "1"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier        = local.rds_identifier
  engine            = "postgres"
  engine_version    = local.rds_pg_version
  instance_class    = local.rds_instance_class
  allocated_storage = 5
  storage_encrypted = false
  port              = local.rds_pg_port

  db_name                 = local.rds_db_name
  username                = local.rds_user
  password                = local.rds_pg_user_password
  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 0
  deletion_protection     = false

  vpc_security_group_ids = [data.aws_security_group.default.id]
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  parameter_group_name   = aws_db_parameter_group.replication.name
}

# Managed Service infrastructure

# Network resources

resource "yandex_vpc_network" "network" {
  description = "Network for the Managed Service for PostgreSQL cluster"
  name        = local.network_name
}

# NAT gateway
resource "yandex_vpc_gateway" "postgres_nat" {
  name = "postgres-nat"
  shared_egress_gateway {}
}

# Route table
resource "yandex_vpc_route_table" "postgres_rt" {
  network_id = yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.postgres_nat.id
  }
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  route_table_id = yandex_vpc_route_table.postgres_rt.id
}

resource "yandex_vpc_security_group" "security-group" {
  description = "Security group for the Managed Service for PostgreSQL cluster"
  name        = local.security_group_name
  network_id  = yandex_vpc_network.network.id

  ingress {
    description    = "The rule allows connections to the Managed Service for PostgreSQL cluster from the Internet"
    protocol       = "TCP"
    port           = 6432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "The rule allows connections to the Amazon RDS for PostgreSQL instance from the Internet"
    protocol       = "TCP"
    port           = local.rds_pg_port
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

# PostgreSQL cluster

resource "yandex_mdb_postgresql_cluster" "mpg-cluster" {
  description        = "Managed Service for PostgreSQL cluster"
  name               = local.pg_cluster_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  security_group_ids = [yandex_vpc_security_group.security-group.id]

  config {
    version = local.mpg_version
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = "20" # GB
    }
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }
}

# User of the Managed Service for PostgreSQL cluster
resource "yandex_mdb_postgresql_user" "pg-user" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.pg_username
  password   = local.mpg_user_password
}

# Database of the Managed Service for PostgreSQL cluster
resource "yandex_mdb_postgresql_database" "mpg-db" {
  cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
  name       = local.pg_db_name
  owner      = yandex_mdb_postgresql_user.pg-user.name
  depends_on = [
    yandex_mdb_postgresql_user.pg-user
  ]
}

# Transfer

resource "yandex_datatransfer_endpoint" "aws_rds_source" {
  name = "aws-rds-pg-source"
  settings {
    postgres_source {
      connection {
        on_premise {
          hosts = [aws_db_instance.rds_instance.address]
          port  = local.rds_pg_port
          tls_mode {
            enabled {
              ca_certificate = local.aws_certificate
            }
          }
        }
      }
      slot_gigabyte_lag_limit = 100
      database                = local.rds_db_name
      user                    = local.rds_user
      password {
        raw = local.rds_pg_user_password
      }
    }
  }
}


resource "yandex_datatransfer_endpoint" "mpg-target" {
  description = "Target endpoint for PostgreSQL cluster"
  name        = "mpg-target"
  settings {
    postgres_target {
      connection {
        mdb_cluster_id = yandex_mdb_postgresql_cluster.mpg-cluster.id
      }
      database = yandex_mdb_postgresql_database.mpg-db.name
      user     = yandex_mdb_postgresql_user.pg-user.name
      password {
        raw = local.mpg_user_password
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "rds-pg-transfer" {
  count       = local.transfer_enabled
  description = "Transfer from the Amazon RDS for PostgreSQL to the Managed Service for PostgreSQL"
  name        = "transfer-from-rds-to-mpg"
  source_id   = yandex_datatransfer_endpoint.aws_rds_source.id
  target_id   = yandex_datatransfer_endpoint.mpg-target.id
  type        = "SNAPSHOT_AND_INCREMENT" # Copy all data from the source cluster and start replication.
}
