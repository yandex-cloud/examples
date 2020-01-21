output "external_ip" {
  value = yandex_compute_instance_group.ig-with-coi.id
}