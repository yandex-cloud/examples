provider "yandex" {
  service_account_key_file = "${var.service_account_key_file}"
  folder_id                = "${var.folder_id}"
}

data "yandex_compute_image" "nginx_image" {
  family    = "${var.yc_image_family["nginx"]}"
  folder_id = "${var.folder_id}"
}

data "yandex_compute_image" "django_image" {
  family    = "${var.yc_image_family["django"]}"
  folder_id = "${var.folder_id}"
}

resource "yandex_compute_instance" "nginx" {
  count       = "${var.cluster_size}"
  name        = "yc-nginx-instance-${count.index}"
  hostname    = "yc-nginx-instance-${count.index}"
  description = "yc-nginx-instance-${count.index} of my cluster"
  zone        = "${element(var.zones, count.index)}"

  resources {
    cores  = "${var.instance_cores}"
    memory = "${var.instance_memory}"
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.nginx_image.id}"
      type     = "network-nvme"
      size     = "30"
    }
  }


  network_interface {
    subnet_id = "${element(local.subnet_ids, count.index)}"
    nat       = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("${var.public_key_path}")}"
    user-data = "${file("boostrap/metadata.yaml")}"
  }

  labels = {
    node_id = "${count.index}"
  }
}

resource "yandex_compute_instance" "django" {
  count       = "${var.cluster_size}"
  name        = "yc-django-instance-${count.index}"
  hostname    = "yc-django-instance-${count.index}"
  description = "yc-django-instance-${count.index} of my cluster"
  zone        = "${element(var.zones, count.index)}"

  resources {
    cores  = "${var.instance_cores}"
    memory = "${var.instance_memory}"
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.django_image.id}"
      type     = "network-nvme"
      size     = "30"
    }
  }


  network_interface {
    subnet_id = "${element(local.subnet_ids, count.index)}"
    nat       = false
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("${var.public_key_path}")}"
    user-data = "${file("boostrap/metadata.yaml")}"
  }

  labels = {
    node_id = "${count.index}"
  }
}

locals {
  nginx_ips = {
    internal = ["${yandex_compute_instance.nginx.*.network_interface.0.ip_address}"]
    external = ["${yandex_compute_instance.nginx.*.network_interface.0.nat_ip_address}"]
  }
  django_ips = {
    internal = ["${yandex_compute_instance.django.*.network_interface.0.ip_address}"]
    external = ["${yandex_compute_instance.django.*.network_interface.0.nat_ip_address}"]
  }
}
