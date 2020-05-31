variable "yc_oauth_token" {
  description = "YC OAuth token"
  default     = ""
  type        = string
}

variable "yc_cloud_id" {
  description = "ID of a cloud"
  default     = ""
  type        = string
}

variable "yc_folder_id" {
  description = "ID of a folder"
  default     = ""
  type        = string
}

variable "yc_main_zone" {
  description = "The main availability zone"
  default     = "ru-central1-a"
  type        = string
}

variable "default_labels" {
  description = "Set of labels"
  default     = { "env" = "prod", "deployment" = "terraform" }
  type        = map(string)
}

variable "iot_db_name" {
  description = "Name postgre database for storing iot events"
  default     = "iot_events"
  type        = string
}

variable "iot_registry_name" {
  description = "yandex iot example registry title"
  default     = "my_iot_registry"
  type        = string
}

