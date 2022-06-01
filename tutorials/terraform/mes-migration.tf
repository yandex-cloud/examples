# Infrastructure for Yandex Cloud Managed Service for Elasticsearch cluster
#
# RU: https://cloud.yandex.ru/docs/managed-elasticsearch/tutorials/migration-via-snapshots

# Specify the pre-installation parameters
locals {
  folder_id          = "" # Your Folder ID.
  mes_admin_password = "" # Administrator password for Managed Service for Elasticsearch cluster.
  mes_edition        = "" # Managed Service for Elasticsearch destination cluster edition, Basic, Gold or Platinum. See https://cloud.yandex.ru/docs/managed-elasticsearch/concepts/es-editions.
  mes_version        = "" # Managed Service for Elasticsearch destination cluster version, should be newer then source cluster version.
}

resource "yandex_vpc_network" "my-network" {
  description = "Network for Managed Service for Elasticsearch cluster"
  name        = "my-network"
  folder_id   = local.folder_id
}

# Subnet for Managed Service for Elasticsearch cluster
resource "yandex_vpc_subnet" "my-subnet" {
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-network.id
}

resource "yandex_vpc_security_group" "mes-cluster-security-group" {
  description = "Security group for Managed Service for Elasticsearch cluster"
  network_id  = yandex_vpc_network.my-network.id

  # Allow Kibana connections to cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow Kibana connections from the Internet"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Elasticsearch connections to cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow Elasticsearch connections from the Internet"
    port           = 9200
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_iam_service_account" "sa-bucket" {
  description = "Service account for Object Storage Bucket"
  name        = "sa-bucket"
}

data "yandex_resourcemanager_folder" "my-folder" {
  folder_id = local.folder_id
}

# Role to operate with Object Storage Bucket
resource "yandex_resourcemanager_folder_iam_binding" "bucket-creator" {
  folder_id = data.yandex_resourcemanager_folder.my-folder.id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-bucket.id}",
  ]
}

# Object Storage Bucket
resource "yandex_iam_service_account_static_access_key" "my-bucket-key" {
  service_account_id = yandex_iam_service_account.sa-bucket.id
}

resource "yandex_storage_bucket" "my-bucket" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.bucket-creator
  ]

  bucket     = "my-bucket" # Should be unique in Cloud
  access_key = yandex_iam_service_account_static_access_key.my-bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.my-bucket-key.secret_key
}

resource "yandex_mdb_elasticsearch_cluster" "my-mes-cluster" {
  description        = "Managed Service for Elasticsearch cluster"
  name               = "my-mes-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.my-network.id
  security_group_ids = [yandex_vpc_security_group.mes-cluster-security-group.id]
  service_account_id = yandex_iam_service_account.sa-bucket.id

  config {

    version        = local.mes_version
    edition        = local.mes_edition
    admin_password = local.mes_admin_password
    plugins        = ["repository-s3"]

    data_node {
      resources {
        resource_preset_id = "s2.micro"
        disk_type_id       = "network-ssd"
        disk_size          = 10 # Gb
      }
    }

  }

  host {
    name             = "node"
    zone             = "ru-central1-a"
    type             = "DATA_NODE"
    assign_public_ip = true
    subnet_id        = yandex_vpc_subnet.my-subnet.id
  }

  maintenance_window {
    type = "ANYTIME"
  }
}