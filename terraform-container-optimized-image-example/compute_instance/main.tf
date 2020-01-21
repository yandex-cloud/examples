provider "yandex" {
  token = "your YC_TOKEN"
  folder_id = "your folder id"
  zone = "your default zone"
}

resource "yandex_compute_instance" "instance-based-on-coi" {

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.container-optimized-image.id
    }
  }
  network_interface {
    subnet_id = "your subnet id"
    nat       = true
  }
  resources {
    cores  = 2
    memory = 2
  }

  metadata = {
    docker-container-declaration = file("${path.module}/declaration.yaml")
    user-data = file("${path.module}/cloud_config.yaml")
  }
}

data "yandex_compute_image" "container-optimized-image" {
  family    = "container-optimized-image"
}
