resource "yandex_vpc_network" "network" {
  name = "yc-auto-subnet"
}

resource "yandex_vpc_subnet" "subnet" {
  count          = "${var.cluster_size > length(var.zones) ? length(var.zones)  : var.cluster_size}"
  name           = "yc-auto-subnet-${count.index}"
  zone           = "${element(var.zones,count.index)}"
  network_id     = "${yandex_vpc_network.network.id}"
  v4_cidr_blocks = ["192.168.${count.index}.0/24"]
}

locals {
  subnet_ids = ["${yandex_vpc_subnet.subnet.*.id}"]
}
