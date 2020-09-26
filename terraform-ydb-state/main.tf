terraform {
  backend "s3" {
    endpoint                    = "storage.yandexcloud.net"
    dynamodb_endpoint           = "https://docapi.serverless.yandexcloud.net/ru-central1/<CLOUD-ID>/<DATABASE-ID>"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true

    // state will be stored in given bucket and object
    // bucket should be created before `terraform init`
    bucket                      = "<BUCKET-ID>"
    key                         = "terraform-example-state"

    // state lock will be held in given table
    // table should be created before `terrform init`
    // with `LockID` column as Primary Key (`string`)
    dynamodb_table              = "tf_lock"

    // We're not writing access_key and secret_key here
    // for security reasons (it's easy to commit in VCS)
    //
    // Use command line arguments for `terraform init` like:
    //     -backend-config="secret_key=<secret_value>"
  }
}

