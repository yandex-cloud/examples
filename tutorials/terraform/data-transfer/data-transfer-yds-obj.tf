# Infrastructure for the Yandex Cloud Data Streams, Object Storage, and Data Transfer.
#
# RU: https://cloud.yandex.ru/docs/data-transfer/tutorials/yds-to-objstorage
# EN: https://cloud.yandex.com/en/docs/data-transfer/tutorials/yds-to-objstorage
#
# Set source cluster and target database settings.
locals {
  folder_id = "" # Your Folder ID.
  sa_name   = "" # Set a service account name. It must be unique in a cloud.

  # Source database settings:
  source_db_name = "" # Set the source database name.
  #source_endpoint_id = "" # Set the source endpoint id.

  # Target bucket settings:
  bucket_name = "" # Set an Object Storage bucket name. It must be unique throughout Object Storage.
  #target_endpoint_id = "" # Set the target endpoint id.
}

resource "yandex_iam_service_account" "sa-yds-obj" {
  description = "Service account for migration from the Data Streams to Object Storage"
  name        = local.sa_name
}

# Assign the `yds.editor` role to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "yds_editor" {
  folder_id = local.folder_id
  role      = "yds.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

# Assign the `storage.editor` role to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "storage_editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

# Assign the `storage.uploader` role to the service account.
resource "yandex_resourcemanager_folder_iam_binding" "storage_uploader" {
  folder_id = local.folder_id
  role      = "storage.uploader"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa-yds-obj.id}",
  ]
}

resource "yandex_ydb_database_serverless" "ydb" {
  name = local.source_db_name
}

resource "yandex_iam_service_account_static_access_key" "bucket-key" {
  description        = "Object Storage bucket static key"
  service_account_id = yandex_iam_service_account.sa-yds-obj.id
}

# Object Storage bucket
resource "yandex_storage_bucket" "storage-bucket" {
  bucket     = local.bucket_name
  access_key = yandex_iam_service_account_static_access_key.bucket-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.bucket-key.secret_key
}

#resource "yandex_datatransfer_transfer" "yds-obj-transfer" {
#  description = "Transfer from the Data Streams to the Object Storage"
#  name        = "transfer-from-yds-to-objstorage"
#  source_id   = local.source_endpoint_id
#  target_id   = local.target_endpoint_id
#  type        = "INCREMENT_ONLY" # Replication data from the source Data Stream.
#}
