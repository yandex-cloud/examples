resource "yandex_iot_core_registry" "iot_registry_name" {
  name        = "iot_registry_name"
  description = "yandex iot example registry"
  labels = {
    my-label = "yandex-iot-example"
  }
  passwords = [
    random_password.registry.result
  ]
}

resource "yandex_iot_core_device" "iot_device_01_name" {
  registry_id = yandex_iot_core_registry.iot_registry_name.id
  name        = "iot_device_01_name"
  description = "yandex iot example device"
   passwords = [
    random_password.device.result
  ]
}