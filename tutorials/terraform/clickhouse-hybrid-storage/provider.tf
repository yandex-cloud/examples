terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">=0.13"
}

provider "yandex" {
  token     = ""              # Set the OAuth token. For create it use YC CLI command: yc iam create-token
  cloud_id  = ""              # Set the cloud ID
  folder_id = ""              # Set the folder ID
  zone      = "ru-central1-a" # Set the availability zone, ru-central1-a xor ru-central1-b
}
