#!/bin/bash

set -e

NEWLINE=$'\n'

if ! command -v jq &>/dev/null; then
  echo "jq could not be found, please install it https://stedolan.github.io/jq/manual/" >&2
  exit 1
fi

YC_PROFILE=${YC_PROFILE:-default}
if [ -z "$YC_CLOUD_ID" ]; then
  echo "Env variable YC_CLOUD_ID is required" >&2
  exit 1
fi

# Some of cloud entities must have unique name across user's cloud
# So we use this id to avoid name conflicts
APP_ID=$(xxd -l 2 -c 2 -p </dev/random)
echo "App id $APP_ID"

TMP_DIR=$(mktemp -d)
function cleanup() {
  echo "Cleanup dir ${TMP_DIR}"
  rm -rf $TMP_DIR
}
trap cleanup EXIT

function run_yc() {
  yc --profile "$YC_PROFILE" --format json "$@"
}

echo 'Creating infra folder'
INFRA_FOLDER_ID=$(run_yc resource-manager folder create --cloud-id "$YC_CLOUD_ID" --name "cart-infra-$APP_ID" | jq -r .id)

echo 'Creating container registry'
REGISTRY_ID=$(run_yc container registry create --name 'app-images' --folder-id "$INFRA_FOLDER_ID" | jq -r .id)

echo 'Creating builder service account'
BUILDER_SA_ID=$(run_yc iam service-account create --name "builder-$APP_ID" --folder-id "$INFRA_FOLDER_ID" | jq -r .id)

echo 'Creating builder service account static key'
BUILDER_SA_KEY_PATH="$TMP_DIR/builder-sa-key.json"
run_yc iam key create --service-account-id "$BUILDER_SA_ID" default-sa -o "$BUILDER_SA_KEY_PATH"
GH_SECRETS="${GH_SECRETS}${NEWLINE}${NEWLINE}SA_BUILDER_PRIVATE_KEY: $(cat $BUILDER_SA_KEY_PATH)"

echo 'Granting container registry permissions to builder service account'
yc --profile "$YC_PROFILE" container registry add-access-binding --id "$REGISTRY_ID" --role container-registry.images.pusher --service-account-id "$BUILDER_SA_ID"
yc --profile "$YC_PROFILE" container registry add-access-binding --id "$REGISTRY_ID" --role container-registry.images.puller --service-account-id "$BUILDER_SA_ID"

echo 'Templating infra.yaml config'
REGISTRY_ID="$REGISTRY_ID" envsubst <config/infra.yaml.tpl >"config/infra.yaml"

function create_environment() {
  ENV_NAME=$1
  ENV_NAME_UPPER=$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')

  echo "Creating folder for $ENV_NAME environment"
  ENV_FOLDER_ID=$(run_yc resource-manager folder create --cloud-id "$YC_CLOUD_ID" --name "cart-$ENV_NAME-$APP_ID" | jq -r .id)

  echo "Creating serverless database for $ENV_NAME environment"
  YDB_JSON=$(run_yc ydb database create --serverless --folder-id "$ENV_FOLDER_ID" --name "cart-db")
  DOCAPI_ENDPOINT=$(echo "$YDB_JSON" | jq -r .document_api_endpoint)
  DB_ID=$(echo "$YDB_JSON" | jq -r .id)
  DB_STATUS=$(echo "$YDB_JSON" | jq -r .status)

  echo "Creating deployer service account for $ENV_NAME environment"
  DEPLOYER_SA_ID=$(run_yc iam service-account create --name "deployer-$ENV_NAME-$APP_ID" --folder-id "$ENV_FOLDER_ID" | jq -r .id)

  echo "Creating $ENV_NAME deployer service account static key"
  ENV_DEPLOYER_SA_KEY_PATH="$TMP_DIR/$ENV_NAME-deployer-sa-key.json"
  run_yc iam key create --service-account-id "$DEPLOYER_SA_ID" default-sa -o "$ENV_DEPLOYER_SA_KEY_PATH"
  GH_SECRETS="${GH_SECRETS}${NEWLINE}${NEWLINE}SA_${ENV_NAME_UPPER}_DEPLOYER_PRIVATE_KEY: $(cat $ENV_DEPLOYER_SA_KEY_PATH)"

  echo "Granting editor role to $ENV_NAME deployer service account"
  yc --profile "$YC_PROFILE" resource-manager folder add-access-binding --id "$ENV_FOLDER_ID" --role editor --service-account-id "$DEPLOYER_SA_ID"

  echo "Creating api gateway service account for $ENV_NAME environment"
  CART_GATEWAY_SA_ID=$(run_yc iam service-account create --name "cart-apigw-$ENV_NAME-$APP_ID" --folder-id "$ENV_FOLDER_ID" | jq -r .id)

  echo "Granting container invoker role to $ENV_NAME api gateway service account"
  yc --profile "$YC_PROFILE" resource-manager folder add-access-binding --id "$ENV_FOLDER_ID" --role serverless.containers.invoker --service-account-id "$CART_GATEWAY_SA_ID"

  echo "Creating cart app service account for $ENV_NAME environment"
  CART_APP_SA_ID=$(run_yc iam service-account create --name "cart-app-$ENV_NAME-$APP_ID" --folder-id "$ENV_FOLDER_ID" | jq -r .id)

  echo "Creating docapi access key for $ENV_NAME cart app service account"
  AWS_KEY_JSON=$(run_yc iam access-key create --service-account-id "$CART_APP_SA_ID")
  AWS_KEY_ID=$(echo "$AWS_KEY_JSON" | jq -r .access_key.key_id)
  AWS_KEY_SECRET=$(echo "$AWS_KEY_JSON" | jq -r .secret)

  echo "Granting local folder permissions for $ENV_NAME cart app service account"
  yc --profile "$YC_PROFILE" resource-manager folder add-access-binding --id "$ENV_FOLDER_ID" --role lockbox.payloadViewer --service-account-id "$CART_APP_SA_ID"
  yc --profile "$YC_PROFILE" resource-manager folder add-access-binding --id "$ENV_FOLDER_ID" --role ydb.editor --service-account-id "$CART_APP_SA_ID"

  echo "Granting infra folder images puller permission for $ENV_NAME cart app service account"
  yc --profile "$YC_PROFILE" container registry add-access-binding --id "$REGISTRY_ID" --role container-registry.images.puller --service-account-id "$CART_APP_SA_ID"

  echo "Creating application secret for $ENV_NAME environment"
  DJANGO_SECRET=$(xxd -l 32 -c 32 -p </dev/urandom)
  SECRET_PAYLOAD=$(jq -n '[{key: "AWS_ACCESS_KEY_ID", text_value: $aws_key_id}, {key: "AWS_SECRET_ACCESS_KEY", text_value: $aws_key_secret}, {key: "SECRET_KEY", text_value: $django_secret_key}]' \
    --arg aws_key_id "$AWS_KEY_ID" \
    --arg aws_key_secret "$AWS_KEY_SECRET" \
    --arg django_secret_key "$DJANGO_SECRET")
  APP_SECRET_ID=$(run_yc lockbox secret create --name 'cart-app' --folder-id "$ENV_FOLDER_ID" --payload "$SECRET_PAYLOAD" | jq -r .id)

  echo "Waiting DB running state"
  while [[ "$DB_STATUS" != "RUNNING" ]]; do
    echo "Current state: $DB_STATUS"
    DB_STATUS=$(run_yc ydb database get "$DB_ID" | jq -r .status)
  done

  echo "Creating DB schema"
  DOCAPI_ENDPOINT="$DOCAPI_ENDPOINT" \
    YC_SA_KEY="$(cat $ENV_DEPLOYER_SA_KEY_PATH)" \
    SECRET_ID="" \
    SECRETS_IN_ENV="AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,SECRET_KEY" \
    AWS_ACCESS_KEY_ID="$AWS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$AWS_KEY_SECRET" \
    SECRET_KEY="$DJANGO_SECRET" \
    python application/manage.py bootstrap_db

  echo "Templating $ENV_NAME.yaml config"
  FOLDER_ID="$ENV_FOLDER_ID" \
    CONTAINER_SA_ID="$CART_APP_SA_ID" \
    CONTAINER_SECRET_ID="$APP_SECRET_ID" \
    APIGW_SA_ID="$CART_GATEWAY_SA_ID" \
    DOCAPI_ENDPOINT="$DOCAPI_ENDPOINT" \
    envsubst <config/$ENV_NAME.yaml.tpl >config/$ENV_NAME.yaml

}

create_environment prod
create_environment testing
create_environment feature

echo "Please, add following secrets to your github repo:$GH_SECRETS"
