# Infrastructure for Yandex Cloud Managed Service for Elasticsearch cluster
#
# RU: https://cloud.yandex.ru/docs/managed-elasticsearch/tutorials/migration-via-snapshots
# EN: https://cloud.yandex.com/en/docs/managed-elasticsearch/tutorials/migration-via-snapshots

# Specify the pre-installation parameters
locals {
  folder_id          = "" # Your Folder ID.
  mes_admin_password = "" # Administrator password for Managed Service for Elasticsearch cluster.
  mes_edition        = "" # Managed Service for Elasticsearch destination cluster edition, Basic or Platinum. See https://cloud.yandex.ru/docs/managed-elasticsearch/concepts/es-editions.
  mes_version        = "" # Managed Service for Elasticsearch destination cluster version, should be equal or newer than source cluster version.
  bucket_name        = "" # Object Storage bucket name. Should be unique in Cloud.
}

resource "yandex_vpc_network" "my-network" {
  description = "Network for the Managed Service for Elasticsearch cluster"
  name        = "my-network"
}

resource "yandex_vpc_subnet" "my-subnet" {
  description    = "Subnet for the Managed Service for Elasticsearch cluster"
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-network.id
}

resource "yandex_vpc_security_group" "mes-cluster-security-group" {
  description = "Security group for the Managed Service for Elasticsearch cluster"
  network_id  = yandex_vpc_network.my-network.id

  ingress {
    description    = "Allow Kibana connections from the Internet"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow Elasticsearch connections from the Internet"
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_iam_service_account" "sa-bucket" {
  description = "Service account for the Object Storage Bucket"
  name        = "sa-bucket"
}

resource "yandex_iam_service_account" "sa-mes-cluster" {
  description = "Service account for the Managed Service for Elasticsearch cluster"
  name        = "sa-mes-cluster"
}

# Role to operate with Object Storage Bucket
resource "yandex_resourcemanager_folder_iam_binding" "bucket-creator" {
  folder_id = local.folder_id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-bucket.id}",
  ]
}

# Role to operate with the Managed Service for Elasticsearch cluster
resource "yandex_resourcemanager_folder_iam_binding" "mes-cluster-creator" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-mes-cluster.id}",
  ]
}

resource "yandex_iam_service_account_static_access_key" "my-bucket-key" {
  description        = "Static access key for Object Storage Bucket"
  service_account_id = yandex_iam_service_account.sa-bucket.id
}

# Object Storage Bucket
resource "yandex_storage_bucket" "my-bucket" {
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.bucket-creator
  ]

  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.my-bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.my-bucket-key.secret_key
}

resource "yandex_mdb_elasticsearch_cluster" "my-mes-cluster" {
  description        = "Managed Service for Elasticsearch cluster"
  name               = "my-mes-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.my-network.id
  security_group_ids = [yandex_vpc_security_group.mes-cluster-security-group.id]
  service_account_id = yandex_iam_service_account.sa-mes-cluster.id
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.mes-cluster-creator
  ]

  config {
    version        = local.mes_version
    edition        = local.mes_edition
    admin_password = local.mes_admin_password
    plugins        = ["repository-s3"]

    data_node {
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
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
}
