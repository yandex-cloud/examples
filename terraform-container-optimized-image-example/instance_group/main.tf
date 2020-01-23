locals {
  user = "yc-user"
  token = "your YC_TOKEN"
  folder_id = "your folder id"
  service_account_id = "your service account id"
  zone = "your zone"
  network_id = "your network id"
  subnet_ids = ["your subnet ids"]
  zones = ["your zones"]
}

provider "yandex" {
  token = local.token
  folder_id = local.folder_id
  zone = local.zone
}

resource "yandex_compute_instance_group" "ig-with-coi" {
  name               = "test-ig-1"
  folder_id          = local.folder_id
  service_account_id = local.service_account_id
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory = 1
      cores  = 1
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.container-optimized-image.id
      }
    }
    network_interface {
      network_id = local.network_id
      subnet_ids = local.subnet_ids
    }

    metadata = {
      docker-container-declaration = file("${path.module}/declaration.yaml")
      user-data = data.template_file.cloud-config.rendered
    }
    service_account_id = local.service_account_id
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = local.zones
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
}

data "yandex_compute_image" "container-optimized-image" {
  family    = "container-optimized-image"
}

data "template_file" "cloud-config" {
  template = file("${path.module}/cloud_config.tpl")
  vars = {
    user = local.user
    ssh-key = file("~/.ssh/id_rsa.pub")
  }
}
