provider "yandex" {
#  token                   = "oAuth token, see https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
#  ymq_access_key          = "Access key ID, see https://cloud.yandex.ru/docs/iam/operations/sa/create-access-key"
#  ymq_secret_key          = "Secret access key, see https://cloud.yandex.ru/docs/iam/operations/sa/create-access-key"
  cloud_id                 = "your-cloud-id"
  folder_id                = "your-folder-id"
  zone                     = "ru-central1-a"
}

# Use this syntax to reference pre-existing message queues
# data "yandex_message_queue" "existing_queue" {
#   name = "existing_queue"
# }

resource "yandex_message_queue" "tf_example_queue" {
  name                        = "ymq_terraform_example"
  visibility_timeout_seconds  = 600
  receive_wait_time_seconds   = 15
  message_retention_seconds   = 1209600
  # Use this syntax to specify redrive_policy in JSON format
  # and to refer existing queue
  # redrive_policy              = jsonencode({
  #  deadLetterTargetArn = data.yandex_message_queue.existing_queue.arn
  #  maxReceiveCount     = 3
  # })
}

