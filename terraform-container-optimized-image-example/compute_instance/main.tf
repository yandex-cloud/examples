locals {
  user = "yc-user"
  token = "your YC_TOKEN"
  folder_id = "your folder id"
  zone = "your zone"
  subnet_id = "your subnet id"
}

provider "yandex" {
  token = local.token
  folder_id = local.folder_id
  zone = local.zone
}

resource "yandex_compute_instance" "instance-based-on-coi" {

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.container-optimized-image.id
    }
  }
  network_interface {
    subnet_id = local.subnet_id
    nat       = true
  }
  resources {
    cores  = 2
    memory = 2
  }

  metadata = {
    docker-container-declaration = file("${path.module}/declaration.yaml")
    user-data = data.template_file.cloud-config.rendered
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
