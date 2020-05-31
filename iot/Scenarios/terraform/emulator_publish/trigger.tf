resource "yandex_function_trigger" "emulator_publish_trigger" {
  name        = "emulator-publish"
  description = "Publish by timeout to Emulator's devices"
  timer {
    cron_expression = var.publish_cron_expression
  }
  function {
    id                 = yandex_function.emulator_publish_func.id
    service_account_id = yandex_iam_service_account.emulator_sa.id
  }
}
