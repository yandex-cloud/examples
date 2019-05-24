##########
# terraform
##########

terraform {
  required_version = "= 0.11.13"

  backend "s3" {}
}

##########
# provider
##########

provider "yandex" {
  service_account_key_file = "${var.service_account_key_file}"
  cloud_id                 = "${var.cloud_id}"
  folder_id                = "${var.folder_id}"
}

##########
# network
##########

resource "yandex_vpc_network" "vpc_ad" {
  name = "${var.vpc_name}"
}

resource "yandex_vpc_subnet" "subnet_ad" {
  count = "${length(var.zone_names)}"

  name           = "${var.subnet_name}-${element(var.zone_short_names, count.index)}"
  zone           = "${element(var.zone_names, count.index)}"
  v4_cidr_blocks = ["${cidrsubnet("${var.subnet_cidr}", 8, count.index)}"]
  network_id     = "${yandex_vpc_network.vpc_ad.id}"
}

##########
# instance
##########

data "yandex_compute_image" "win16" {
  family = "${var.boot_disk_image_family}"
}

resource "yandex_compute_instance" "ad" {
  count = "${var.number}"

  name     = "${element(var.zone_short_names, count.index)}-${var.name}${(count.index) / length(var.zone_names) + 1}"
  hostname = "${element(var.zone_short_names, count.index)}-${var.name}${(count.index) / length(var.zone_names) + 1}"
  zone     = "${element(var.zone_names, count.index)}"

  resources {
    cores  = "${var.cores}"
    memory = "${var.memory}"
  }

  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.win16.id}"
      size     = "${var.boot_disk_size}"
    }
  }

  network_interface {
    subnet_id = "${element(yandex_vpc_subnet.subnet_ad.*.id, count.index)}"
  }

  metadata {
    user      = "${var.user}"
    pass      = "${var.pass}"
    user-data = "${local._user_data}"

    deploy      = "${count.index == 0 ? local._deploy_root : local._deploy_dc }"
    domainname  = "${var.ad_domainname}"
    smadminpass = "${var.ad_smadminpass}"
    forestroot  = "${element(var.zone_short_names, 0)}-${var.name}1"
    cidrs       = "${join(",", yandex_vpc_subnet.subnet_ad.*.v4_cidr_blocks.0)}"
    sites       = "${join(",",var.zone_names)}"
  }
}
