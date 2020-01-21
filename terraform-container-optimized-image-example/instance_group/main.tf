provider "yandex" {
  token = "your YC_TOKEN"
  folder_id = "your folder id"
  zone = "your default zone"
}

resource "yandex_compute_instance_group" "ig-with-coi" {
  name               = "test-ig"
  folder_id          = "your folder id"
  service_account_id = "your service account id"
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
      network_id = "your network id"
      subnet_ids = ["all your subnet ids"]
    }

    metadata = {
      docker-container-declaration = file("${path.module}/declaration.yaml")
      user-data = file("${path.module}/cloud_config.yaml")
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["all your availability zones"]
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
