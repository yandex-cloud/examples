variable "public_key_path" {
  description = "Path to public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "service_account_key_file" {
  description = "Yandex Cloud service account key file in json format"
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID where resources will be created"
}


variable "zone" {
  description = "Yandex Cloud default Zone for provisioned resources"
  default     = "ru-central1-b"
}


variable "zones" {
  description = "Yandex Cloud default Zone for provisioned resources"
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-c"]
}

variable "yc_image_family" {
  description = "family"

  type = "map"

  default = {
    nginx  = "debian-10-nginx"
    django = "debian-10-django"
    base   = "debian-10-base"
  }
}

variable "cluster_size" {
  default = 3
}

variable "instance_cores" {
  description = "Cores per one instance"
  default     = "2"
}

variable "instance_memory" {
  description = "Memory in GB per one instance"
  default     = "2"
}
