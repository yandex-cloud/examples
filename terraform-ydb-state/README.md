# Terraform State

This examples shows how to store Terraform state in Yandex.Cloud using
Object Storage and Yandex Database Serverless services.

## Setup

1. Create Yandex Database in Serverless mode and write down `Document API Endpoint` (long URL).
2. Create Document table (not YDB) with `LockID` primary key (`string` type) as described in Terraform docs.
3. Create Object Storage bucket with limited access.
4. Create Service Account and grant it `ydb.admin` and `storage.editor` roles.
5. Issue Static Credentials for this Service Account and write down Access Key and Secret Key.

## Initialize

Edit `main.tf` and fill necessary fields (`bucket`, `dynamodb_endpoint`), then call

    terraform init -backend-config="access_key=<ACCESS_KEY>" -backend-config="secret_key=<SECRET_KEY>"

using credentials stored at step 5 from setup list.

## Use

Just use Terraform as usual and it will store state file in Object Store and will acquire/release
lock in Yandex Database table to prevent simultaneous operations.
