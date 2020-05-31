output "vpc_network_id" {
  value = yandex_vpc_network.vpc_network.id
}

output "subnet_ids_by_zones" {
  value = {
    for instance in yandex_vpc_subnet.subnet :
    instance.zone => instance.id
  }
}

output "subnet_ids_by_names" {
  value = {
    for instance in yandex_vpc_subnet.subnet :
    instance.name => instance.id
  }
}

output "subnet_v4_blocks_by_zones" {
  value = {
    for instance in yandex_vpc_subnet.subnet :
    instance.zone => instance.v4_cidr_blocks
  }
}

output "subnets_ids" {
  value = "${yandex_vpc_subnet.subnet.*.id}"
}
