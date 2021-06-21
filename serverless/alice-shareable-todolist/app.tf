locals {
  app-env-vars = {
    DOMAIN                 = var.domain
    YANDEX_OAUTH_CLIENT_ID = var.oauth-client-id
    DATABASE               = var.database
    DATABASE_ENDPOINT      = var.database-endpoint
    KMS_KEY_ID             = yandex_kms_symmetric_key.app-key.id
    ENCRYPTED_SECRETS      = yandex_kms_secret_ciphertext.secure-config.ciphertext
  }
}

resource "yandex_function" "web-api" {
  entrypoint         = "main.WebHandler"
  memory             = 128
  name               = "todolist-web"
  runtime            = "golang114"
  user_hash          = data.archive_file.app-code.output_base64sha256
  content {
    zip_filename = data.archive_file.app-code.output_path
  }
  environment        = local.app-env-vars
  service_account_id = yandex_iam_service_account.app-sa.id
  execution_timeout  = "3"
}

resource "yandex_function" "alice-api" {
  entrypoint         = "main.AliceHandler"
  memory             = 128
  name               = "todolist-alice"
  runtime            = "golang114"
  user_hash          = data.archive_file.app-code.output_base64sha256
  content {
    zip_filename = data.archive_file.app-code.output_path
  }
  environment        = local.app-env-vars
  service_account_id = yandex_iam_service_account.app-sa.id
  execution_timeout  = "3"
}

resource "yandex_kms_secret_ciphertext" "secure-config" {
  key_id    = yandex_kms_symmetric_key.app-key.id
  plaintext = file(var.secure-config-path)
}

resource "yandex_kms_symmetric_key" "app-key" {
  name = "todolist-app-key"
}

resource "yandex_iam_service_account" "app-sa" {
  name = "todolist-app"
}

resource "yandex_resourcemanager_folder_iam_binding" "app-sa-ydb-admin" {
  folder_id = var.folder-id
  members   = [
    "serviceAccount:${yandex_iam_service_account.app-sa.id}"
  ]
  role      = "ydb.admin"
}

resource "yandex_resourcemanager_folder_iam_binding" "app-sa-key-access" {
  folder_id = var.folder-id
  members   = [
    "serviceAccount:${yandex_iam_service_account.app-sa.id}"
  ]
  role      = "kms.keys.encrypterDecrypter"
}

data "archive_file" "app-code" {
  output_path = "${path.module}/dist/app-code.zip"
  type        = "zip"
  source_dir  = "${path.module}/app"
}

resource "yandex_iam_service_account" "gateway-sa" {
  name = "gateway-sa"
}

resource "yandex_function_iam_binding" "gateway-sa-invoker" {
  members     = [
    "serviceAccount:${yandex_iam_service_account.gateway-sa.id}"
  ]
  role        = "serverless.functions.invoker"
  function_id = yandex_function.web-api.id
}

resource "yandex_resourcemanager_folder_iam_binding" "gateway-sa-storage-viewer" {
  folder_id = var.folder-id
  members   = [
    "serviceAccount:${yandex_iam_service_account.gateway-sa.id}"
  ]
  role      = "storage.viewer"
}

# output
output "gateway-sa-id" {
  value = yandex_iam_service_account.gateway-sa.id
}

output "function-web-id" {
  value = yandex_function.web-api.id
}

# configuration
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  folder_id = var.folder-id
  token     = var.yc-token
}

variable "folder-id" {
  type = string
}

variable "yc-token" {
  type = string
}

variable "domain" {
  type = string
}

variable "oauth-client-id" {
  type = string
}

variable "database" {
  type = string
}

variable "database-endpoint" {
  type = string
}

variable "secure-config-path" {
  type = string
}