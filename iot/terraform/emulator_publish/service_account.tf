resource "yandex_iam_service_account" "emulator_sa" {
  name        = "emulator-sa"
  description = "Service Account for Emulator"
}

resource "yandex_resourcemanager_folder_iam_member" "emulator_sa_invoker" {
  folder_id = var.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.emulator_sa.id}"
  role      = "serverless.functions.invoker"
}

resource "yandex_resourcemanager_folder_iam_member" "emulator_sa_writer" {
  folder_id = var.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.emulator_sa.id}"
  role      = "iot.devices.writer"
}

resource "yandex_resourcemanager_folder_iam_member" "emulator_sa" {
  folder_id   = var.folder_id
  member      = "serviceAccount:${yandex_iam_service_account.emulator_sa.id}"
  role        = "viewer"
  sleep_after = 30
  depends_on = [
    yandex_resourcemanager_folder_iam_member.emulator_sa_invoker,
    yandex_resourcemanager_folder_iam_member.emulator_sa_writer
  ]
}