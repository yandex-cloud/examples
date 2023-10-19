# Infrastructure for Yandex Object Storage
#
# Set the configuration of Object Storage objects:
locals {
  rodents_path = "" # Relative or absolute path to the poster_rodents_bunnysize.jpg image
  bunny_path   = "" # Relative or absolute path to the poster_bunny_bunnysize.jpg image
  cc_path      = "" # Relative or absolute path to the cc.xlarge.png image

  # The following setting is predefined. Do not change it as the Object Storage bucket has already been created.
  bucket_name  = "images-for-thumbor" # Name of the bucket
}

# Upload the poster_rodents_bunnysize.jpg image into the bucket
resource "yandex_storage_object" "rodents-image" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.bucket_name
  key        = "poster_rodents_bunnysize"
  source     = local.rodents_path
}

# Upload the poster_bunny_bunnysize.jpg image into the bucket
resource "yandex_storage_object" "bunny-image" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.bucket_name
  key        = "poster_bunny_bunnysize"
  source     = local.bunny_path
}

# Upload the cc.xlarge.png image into the bucket
resource "yandex_storage_object" "cc-image" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.bucket_name
  key        = "cc-xlarge"
  source     = local.cc_path
}
