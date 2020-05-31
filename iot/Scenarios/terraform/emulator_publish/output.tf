output "service_account" {
  value = yandex_iam_service_account.emulator_sa.id
}

output "iot_core" {
  value = yandex_iot_core_registry.emulator.id
}

output "function" {
  value = yandex_function.emulator_publish_func.id
}

output "trigger" {
  value = yandex_function_trigger.emulator_publish_trigger.id
}