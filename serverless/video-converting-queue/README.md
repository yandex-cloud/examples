# Video to gif converting service
Sample project for converting video to gif using only serverless components of Yandex Cloud.

# Yandex Services
* [Cloud Functions](https://cloud.yandex.ru/services/functions)
* [Object Storage](https://cloud.yandex.ru/services/storage)
* [Yandex Database](https://cloud.yandex.ru/services/ydb)
* [Message Queue](https://cloud.yandex.ru/services/message-queue)
* [Yandex Lockbox](https://cloud.yandex.ru/services/lockbox)

# Tools
* [Yandex Cloud command line tool](https://cloud.yandex.ru/docs/cli/)

# Prerequisites
We assume that you already have [Yandex Cloud](https://console.cloud.yandex.ru) account with created cloud and folder

# Initialization
## Setting up service account

Create new [service account](https://cloud.yandex.ru/docs/iam/concepts/users/service-accounts). We will use this SA for all interactions between cloud resources.

Grant following roles to this SA:
* storage.viewer
* storage.uploader
* ymq.reader
* ymq.writer
* ydb.admin
* serverless.functions.invoker
* lockbox.payloadViewer

## Creating Lockbox secret with access key
Create [AWS-compatible access key](https://cloud.yandex.ru/docs/iam/concepts/authorization/access-key) for your service account.

Create new [Lockbox secret](https://cloud.yandex.ru/docs/lockbox/quickstart) and place to keys inside:
1. `ACCESS_KEY_ID` - id of your access key
2. `SECRET_ACCESS_KEY` - secret part of your access key

## Creating Message Queue
Create new [Message Queue](https://cloud.yandex.ru/docs/message-queue/operations/message-queue-new-queue). You can use default settings, the only restriction is that queue must be standard, not FIFO

## Creating Object Storage bucket
Just [create bucket](https://cloud.yandex.ru/docs/storage/operations/buckets/create) with default settings.

## Creating Yandex Database and Document API table
1. [Create](https://cloud.yandex.ru/docs/ydb/operations/create_manage_database#create-db) serverless database
2. [Create](https://cloud.yandex.ru/docs/ydb/operations/schema) **document** table named `tasks` with single field `task_id`, set `partitioning key` checkbox

# Deploying API function

[Create function](https://cloud.yandex.ru/docs/functions/operations/function/function-create).

Start creating new version with python 3.7 runtime:
Set up function service account (the one created on previous step). Add function sources: requirements.txt and index.py files from current example's directory.

Specify entrypoint, which is `index.handle_api` for API function.

Setup environment variables:
* `SECRET_ID` - id of Lockbox secret with access key of your service account
* `YMQ_QUEUE_URL` - URL of your message queue
* `DOCAPI_ENDPOINT` - Document API endpoint of your serverless database. Note that you should use Document API endpoint, not YDB endpoint

Create function version

You can now [test your function](https://cloud.yandex.ru/docs/functions/operations/function/function-invoke) from cloud console: upload sample video on [Yandex.Disk](https://disk.yandex.ru) and send it to your function:

`{
  "action": "convert", 
  "src_url": "<video url from Yandex.Disk>"
}`

And then check resulting task status:
`
{
  "action": "get_task_status",
  "task_id": "<task id from previous function call result>"
`

# Deploying converter function
Create new function.

For this function we will require ffmpeg static binary - it can be found on [ffmpeg downloads page](https://ffmpeg.org/download.html). Make sure your download static binary for amd64 architecture.

Pack function sources (requirements.txt, index.py and ffmpeg binary) into `src.zip` archive. **Note**: function sources should be located on top level of zip archive (no nested directories). For mac users: make sure that there is no `__MACOSX` directory in your zip archive.

[Upload](https://cloud.yandex.ru/docs/storage/operations/objects/upload) your zip archive to Object Storage bucket.

Inside your new converter function create new version using python 3.7 runtime:
1. Choose `Object Storage` deploy method instead of code editor
2. Specify bucket and object name of zip archive uploaded to Object Storage
3. Entrypoint for converter function is `index.handle_process_event`
4. Tune function resources: it's recommended to set function execution timeout to 600 seconds and select 2GB of memory
5. Select function service account
6. Setup environment variables as for API function, but add extra `S3_BUCKET` variable with name of your Object Storage bucket
7. Create version

# Setting up trigger
Create [Message Queue trigger](https://cloud.yandex.ru/docs/functions/quickstart/create-trigger/ymq-trigger-quickstart): 
* Choose Message Queue you created as events source
* Use your service account for both accessing Message Queue and invoking cloud function 
* Set your converter function as trigger target.