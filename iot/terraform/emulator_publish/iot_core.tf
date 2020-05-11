resource "yandex_iot_core_registry" "emulator" {
  name        = "emulator-registry"
  description = "Registry for Emulator's devices"

  passwords = [
    "1Test2Sample3Password!"
  ]
}

resource "yandex_iot_core_device" "emulator_device" {
  count       = var.device_count
  registry_id = yandex_iot_core_registry.emulator.id
  name        = "device${count.index + 1}"
  description = "test device"
}