variable "network_id" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "Unique for the cloud name of a cluster"
}

variable "description" {
  type    = string
  default = null
}

variable "environment" {
  type        = string
  default     = "PRODUCTION"
  description = "PRODUCTION or PRESTABLE. Prestable gets updates before production environment"
}

variable "database_version" {
  type        = string
  default     = "12"
  description = "Version of PostgreSQL"
}

variable "resource_preset_id" {
  type        = string
  default     = "s2.small"
  description = "Id of a resource preset which means count of vCPUs and amount of RAM per host"
}

variable "disk_size" {
  type        = number
  default     = 100
  description = "Disk size in GiB"
}

variable "disk_type_id" {
  type        = string
  default     = "network-ssd"
  description = "Disk type: 'network-ssd', 'network-hdd', 'local-ssd'"
}

variable "labels" {
  type = map
  default = {
    deployment = "terraform"
  }
}


variable "users" {
  type = list(object(
    {
      name     = string
      password = string
    }
  ))
  default = [
    {
      name     = "user1"
      password = ""
    }
  ]
}

variable "user_permissions" {
  type = map(list(object(
    {
      database_name = string
    }
  )))
  default = {
    "user1" : [
      {
        database_name = "db1"
      }
    ]
  }
}

variable "databases" {
  type = list(object({
    name  = string
    owner = string
  }))
  default = [{
    name  = "db1"
    owner = "user1"
  }]
}

variable "hosts" {
  type = list(object({
    zone             = string
    subnet_id        = string
    assign_public_ip = bool
  }))
}

resource "random_password" "pwd" {
  length           = 18
  special          = true
  override_special = "_!%@"
}


resource "yandex_mdb_postgresql_cluster" "managed_postgresql" {
  name        = var.cluster_name
  network_id  = var.network_id
  description = var.description
  labels      = var.labels
  environment = var.environment

  config {
    version = var.database_version
    resources {
      resource_preset_id = var.resource_preset_id
      disk_size          = var.disk_size
      disk_type_id       = var.disk_type_id
    }
  }

  dynamic "user" {
    for_each = var.users
    content {
      name     = user.value.name
      password = user.value.password == "" || user.value.password == null ? random_password.pwd.result : user.value.password

      dynamic "permission" {
        for_each = var.user_permissions[user.value.name]
        content {
          database_name = permission.value.database_name
        }
      }
    }
  }

  dynamic "database" {
    for_each = var.databases
    content {
      name  = database.value.name
      owner = database.value.owner
    }
  }

  dynamic "host" {
    for_each = var.hosts
    content {
      zone             = host.value.zone
      subnet_id        = host.value.subnet_id
      assign_public_ip = host.value.assign_public_ip
    }
  }

}
