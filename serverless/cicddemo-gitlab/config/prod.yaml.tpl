folder-id: ${FOLDER_ID}
app-container:
  cores: 1
  memory: 512mb
  core-fraction: 100
  concurrency: 8
  timeout: 10
  sa-id: ${CONTAINER_SA_ID}
  secret-id: ${CONTAINER_SECRET_ID}
apigw:
  sa-id: ${APIGW_SA_ID}
docapi:
  endpoint: ${DOCAPI_ENDPOINT}