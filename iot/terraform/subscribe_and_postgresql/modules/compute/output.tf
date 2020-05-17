
output "internal_ip_address_vm_1" {
  value = "${yandex_compute_instance.tvm_master.network_interface.0.ip_address}"
}

output "internal_ip_address_vm_2" {
  value = "${yandex_compute_instance.tvm.network_interface.0.ip_address}"
}


output "external_ip_address_vm_1" {
  value = "${yandex_compute_instance.tvm_master.network_interface.0.nat_ip_address}"
}

output "fqdn_tvm_master" {
  value = "${yandex_compute_instance.tvm_master.fqdn}"
}

output "fqdn_tvm" {
  value = "${yandex_compute_instance.tvm.fqdn}"
}
