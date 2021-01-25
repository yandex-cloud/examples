## Prerequisites

1. Create YDB Serverless database
2. Create SA in the same folder (`editor`, `ydb.admin`, `serverless.functions.invoker`)
3. Create func
4. Create version:
```bash
yc serverless function version create \
    --function-id=xxx \
    --entrypoint main.Handler \
    --memory=128MB \
    --execution-timeout=15s \
    --service-account-id=zzzz \
    --runtime=golang114 \
    --source-path=./ \
    --environment=DATABASE=/ru-central1/aaa/bbb,ENDPOINT=ydb.serverless.yandexcloud.net:2135
```

## Gateway
Prepare API Gateway specification using template in `./gateway/spec-template.yaml`. Replace all `<function-id>` with id of your function. Replace all `<service-account-id>` with id of service account.

Create API Gateway from specification. You can use UI or cli:
`yc serverless api-gateway create --name demo --spec <path to specification file>`.


You can request gateway using technical domain provided after gateway creation: `curl https://<your-gateway's-domain>/specs`. Gateway should return 401 error at this point, since no authorization provided.

## Data

see ./data folder. Each file there has table spec and sample data.

## Authorization
We used [Yandex Passport API](https://yandex.ru/dev/passport/) for this example. To be able to query example, you should:
1. Add your login for yandex.ru to `authorized_users` table (query draft can be found in `./data/authorized_users.sql` file)
2. Being authorized at yandex.ru with your login, get your OAuth token using [this link](https://oauth.yandex.ru/authorize?response_type=token&client_id=1aae8f1865154cbc86da0d9641d51539)
3. Provide OAuth token when performing requests to gateway: `curl https://<your-gateway's-domain>/specs -H 'Authorization: OAuth <your token>'`
## Requests

### List specializations

#### Request:

```
GET https://<your-gateway's-domain>/specs
```

#### Output:

```json
[
  {
    "id": "ID",
    "name": "NAME"
  }
]
```

### List places

#### Request:

```
GET https://<your-gateway's-domain>/places
```

#### Output:

```json
[
  {
    "id": "ID",
    "name": "NAME"
  }
]
```

### List dates

#### Request:

```
GET https://<your-gateway's-domain>/dates
    ?specId=SPEC_ID
    &placeId=PLACE_ID
```

Optional parameters: `place`

#### Output:

```json
[
  "yyyy-MM-dd"
]
```

### List doctors

#### Request:

```
GET https://<your-gateway's-domain>/doctors
    ?specId=SPEC_ID
    &date=yyyy-MM-dd
    &placeId=PLACE_ID
```

Optional parameters: `placeId`

#### Output:

```json
[
  {
    "id": "ID",
    "name": "NAME"
  }
]
```

### Ask for slots

#### Request:

```
POST https://<your-gateway's-domain>/slots
    ?clientId=ID
    &specId=SPEC_ID
    &date=yyyy-MM-dd
    &placeId=PLACE_ID
    &doctor=DOCTOR1
    &doctor=DOCTOR2
    &excludeSlot=SLOT1
    &excludeSlot=SLOT2
    &cancelSlot=SLOT3
    &cancelSlot=SLOT4
```

Optional parameters: `placeId`, `doctor`, `excludeSlot` and `cancelSlot`

#### Output:

```json
[
  {
    "id": "ID",
    "at": "datetime"
  }
]
```

### Ack slot

#### Request:

```
POST https://<your-gateway's-domain>/slots/<SLOT_ID>/ack
    ?clientId=ID
    &cancelSlot=SLOT1
    &cancelSlot=SLOT2
```

Optional parameters: `cancelSlot`

#### Output:

```json
{
  "id": "ID",
  "at": "datetime",
  "place": "name",
  "spec": "name",
  "doctor": "name"
}
```