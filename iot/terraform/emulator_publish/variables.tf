variable token {
  description = "Yandex Cloud security OAuth token"
  default     = "Enter your token here"
}

variable cloud_id {
  description = "Yandex Cloud Cloud ID where resources will be created"
  default     = "Enter your Cloud ID here"
}

variable folder_id {
  description = "Yandex Cloud Folder ID where resources will be created"
  default     = "Enter your Folder ID here"
}

variable zone {
  description = "Yandex Cloud default Zone for provisoned resources"
  default     = "ru-central1-a"
}

variable "device_count" {
  description = "Count of devices, which be present for emulator"
  default     = "2"
}

variable "subtopic_for_publish" {
  description = "Emulator will publish to $devices/<id>/events/<this subtopic>"
  default     = "emulator"
}

variable "publish_execution_timeout" {
  description = "Timeout for publish execution in seconds"
  default     = "100"
}

variable "publish_cron_expression" {
  description = "Cron expression for publish. Default is every minutes"
  default     = "* * * * ? *"
}
