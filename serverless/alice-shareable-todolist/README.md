# Shareable TODO list Alice skill and site
This example shows simple site and Alice skill for managing TODO lists. This example uses serverless components of Yandex Cloud

# Yandex Services
* [Cloud Functions]()
* [Cloud API Gateway]()
* [Yandex Database]()
* [Yandex Object Storage]()
* [Yandex KMS]()

# Tools
* [Yandex Cloud command line tool](https://cloud.yandex.ru/docs/cli/)
* [go-swagger](https://goswagger.io/install.html)
* [api-spec-converter](https://www.npmjs.com/package/api-spec-converter)
* [jq](https://stedolan.github.io/jq/)
* [Terraform](http://terraform.io)
* [AWS command line tool](https://aws.amazon.com/ru/cli/)
* Node.js
* go

# Prerequisites
We assume that you already have [Yandex Cloud](https://console.cloud.yandex.ru) account with created cloud and folder

# Initialization
## Create Object Storage bucket
Follow [documentation](https://cloud.yandex.ru/docs/storage/quickstart) to create bucket with any name. Bucket name will be used in project configuration.

Configure aws cli following [instructions](https://cloud.yandex.ru/docs/storage/tools/aws-cli).

## Create API Gateway
Create [API Gateway](https://cloud.yandex.ru/docs/api-gateway/) with any name and default specification. Id of created gateway will be used in project configuration.

## Create Yandex Database 
[Find out](https://cloud.yandex.ru/docs/ydb/) how to create Yandex Database in serverless mode. DB schema will be applied later. Database name and endpoint will be used in project configuration

## Create Yandex OAuth application
Go to [Yandex OAuth](http://oauth.yandex.ru) service and create new application.
You can use any name you like.
You should check "WEB service platfrom" and provide at least two callback URIs:
* `<apigateway technical domain>/yandex-oauth`
* `https://social.yandex.net/broker/redirect`

Use technical domain registered for API Gateway you created earlier.

You should check `login:avatar` permission so that your serverless site can use Yandex user's avatar image.
  
# Configuring project
## Common variables
Create `variables.json` file in project root with values filled with values for your project. You can use `variables-template.json` as template for this step

* `folder-id` - your Yandex Cloud folder id
* `domain` - your site's domain (e.g. API Gateway's technical domain)
* `oauth-client-id` - ID of your registered Yandex OAuth application
* `database` - Yandex Database name
* `database-endpoint` - Yandex Database endpoint
* `yc-profile` - Yandex Cloud command line tool profile name
* `secure-config-path` - path to JSON config with secrets
* `storage-bucket` - Yandex Object Storage bucket name
* `gateway-id` - id of your API Gateway

## Secret variables
Create `secure-config.json` file anywhere on your machine (don't forget to refer to it's destination from `variables.json`). Use `secure-config-template.json` as template for your file

* `session_keys` - generated secret keys used in session management
Keys can be generated:
  * **hash** - base64-encoded 64-bytes random value
  * **block** - base64-encoded 32-bytes random value
* `oauth_secret` - secret (password) of Yandex OAuth application you created

# Deploying

## Apply DB schema
Run `./upload_ydb_schema.sh`

## Deploy functions

Functions can be deployed using [terraform](http://terraform.io). After terraform initialized, you can deploy your application with

`terraform apply -var-file ./variables.json -var yc-token=<OAuth token>`

Where `OAuth token` - [OAuth token](https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token) for your cloud

## Upload static
Go to `frontend` directory and build static files with

`npm run build`

Run `./upload_static.sh` at project root to upload static files to Object Storage.

## Update API Gateway
Run `./update_gateway.sh` to update gateway specification.

Note that at this point your functions should already be deployed with terraform since gateway update script uses terraform's output values to link gateway specification with your function

# Creating Alice skill
Alice skill can be registered in [Yandex Dialogs console](https://dialogs.yandex.ru)
You can choose arbitrary values for your skill's settings, but theses are required:

## Backend
You should choose "Function in Yandex Cloud" backend and use `todolist-alice` function that were deployed earlier with terraform

## Storage
You should check "Storage" checkbox so that your skill will be able to store dialog state.

## Account linking
This settings section describes how Yandex Alice should authenticate on your site. In our example you should use Yandex OAuth settings.

* `Application identity` - id of your Yandex OAuth application
* `Application secret` - secret (password) of your Yandex OAuth application
* `Authorization url` - `https://oauth.yandex.ru/authorize`
* `URL for token receive` - `https://oauth.yandex.ru/token`
* `URL for token refresh` - `https://oauth.yandex.ru/token`

## Intents
Use intent definitions provided in `intents` folder of this project to configure Alice skill intents

Intent file name must be used as intent ID (e.g. for `./intents/cancel.txt` configure intent `cancel` in dialogs settings).
Intent file content provides intent grammar - paste it as is into corresponding settings field.


# Development
Source of truth for OpenAPI 3.0 specification is placed in `./gateway/openapi-template.yaml`, all other OpenAPI and Swagger files are generated from this one. If you want to change an API - you should change only `openapi-template.yaml` file and then generate the rest with

`./generate_code.sh`