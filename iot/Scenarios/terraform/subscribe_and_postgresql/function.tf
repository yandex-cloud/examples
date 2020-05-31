data "archive_file" "function_packer" {
  output_path = "${path.module}/iotadapter.zip"
  source_file = "iotadapter.py"
  type        = "zip"
}


resource "yandex_function" "iotadapter" {
  name               = "iotadapter"
  description        = "serverless function take incomming events from IoT Core and store this events in PostgreSql Db"
  user_hash          = "any_user_defined_string"
  runtime            = "python37"
  entrypoint         = "iotadapter.msgHandler"
  memory             = "128"
  execution_timeout  = "10"
  service_account_id =  yandex_iam_service_account.sa.id
  tags               = ["yandex-iot-example"]
  content {
    zip_filename = "iotadapter.zip"
  }
  environment        = {
    DB_HOSTNAME  = "${module.managed_pgsql_iot_testing.cluster_hosts_fqdns[0][0]}"
    DB_PORT      = 6432
    DB_USER      = "iot_db_user"
    DB_PASSWORD  = "${module.managed_pgsql_iot_testing.cluster_users_passwords["iot_db_user"]}"
    DB_NAME      = var.iot_db_name
    VERBOSE_LOG  = "True"
  }
  depends_on     = [yandex_resourcemanager_folder_iam_member.invoker-svc-iam]
}

resource "yandex_function_trigger" "iot_device_01" {
  name        = "dev-${yandex_iot_core_device.iot_device_01_name.id}-trigger"
  description = "trigger for incomming iot messages for iot_device_01"
  iot  {
      registry_id = yandex_iot_core_registry.iot_registry_name.id
      device_id = yandex_iot_core_device.iot_device_01_name.id
      topic = "$devices/${yandex_iot_core_device.iot_device_01_name.id}/#"
  }
  function  {
    id = yandex_function.iotadapter.id
    service_account_id = yandex_iam_service_account.sa.id
  }
}
