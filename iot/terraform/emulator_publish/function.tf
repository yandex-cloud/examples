resource "yandex_function" "emulator_publish_func" {
  name              = "emulator-publish-func"
  description       = "Publish to Emulator's devices"
  user_hash         = "change hash when publish function changed"
  runtime           = "nodejs12-preview"
  entrypoint        = "iot_data.handler"
  memory            = "128"
  execution_timeout = var.publish_execution_timeout
  content {
    zip_filename = data.archive_file.publish_zip.output_path
  }
  service_account_id = yandex_iam_service_account.emulator_sa.id
  depends_on         = [yandex_resourcemanager_folder_iam_member.emulator_sa]
}
