variable "network_name" {
  type    = string
  default = "default"
}

variable "network_id" {
  type    = string
  default = ""
}

variable "subnets" {
  type = map(object({
    zone           = string
    v4_cidr_blocks = list(string)
  }))
}

resource "yandex_vpc_network" "vpc_network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  count = length(keys(var.subnets))

  name           = keys(var.subnets)[count.index]
  zone           = lookup(var.subnets, keys(var.subnets)[count.index]).zone
  v4_cidr_blocks = lookup(var.subnets, keys(var.subnets)[count.index]).v4_cidr_blocks
  network_id     = yandex_vpc_network.vpc_network.id
}
