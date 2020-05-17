provider "yandex" {
  version   = "~> 0.29"
  token     = var.yc_oauth_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_main_zone
}


resource "random_password" "password" {
  length = 16
  special = true
  min_special = 1
  upper = true
  min_upper = 1
  lower = true
  min_lower = 1
  number = true
  min_numeric = 1
  override_special = "_%@"
}


output "yandex_iot_core_device_iot_device_01_id" {
  value = "${yandex_iot_core_device.iot_device_01_name.id}"
}

output "yandex_iot_core_device_iot_device_01_passwords" {
  value = "${yandex_iot_core_device.iot_device_01_name.passwords}"
}

output "managed_pgsql_iot_testing_cluster_fqdns" {
  value = module.managed_pgsql_iot_testing.cluster_hosts_fqdns
}

output "managed_pgsql_iot_testing_cluster_users" {
  value = module.managed_pgsql_iot_testing.cluster_users
}

output "managed_pgsql_iot_testing_cluster_users_passwords" {
  value     = module.managed_pgsql_iot_testing.cluster_users_passwords
  sensitive = false
}

output "managed_pgsql_iot_testing_cluster_databases" {
  value = module.managed_pgsql_iot_testing.cluster_databases
}

output "yandex_iot_core_registry_iot_registry_passwords" {
  value = "${yandex_iot_core_registry.iot_registry_name.passwords}"
}