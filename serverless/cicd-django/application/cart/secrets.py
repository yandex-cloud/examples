import json
import os

import yandexcloud
from yandex.cloud.lockbox.v1.payload_service_pb2 import GetPayloadRequest
from yandex.cloud.lockbox.v1.payload_service_pb2_grpc import PayloadServiceStub

ENV_SA_KEY = 'YC_SA_KEY'
ENV_SECRETS_IN_ENV = 'SECRETS_IN_ENV'


def load_secret(secret_id):
    res = dict()
    if ENV_SECRETS_IN_ENV in os.environ:
        secret_names_str = os.environ[ENV_SECRETS_IN_ENV]
        secret_names = secret_names_str.split(",")
        for secret_name in secret_names:
            res[secret_name] = os.environ[secret_name]
        return res

    if ENV_SA_KEY in os.environ:
        yc_sdk = yandexcloud.SDK(service_account_key=json.loads(os.environ[ENV_SA_KEY]))
    else:
        yc_sdk = yandexcloud.SDK()
    lockbox = yc_sdk.client(PayloadServiceStub)
    response = lockbox.Get(GetPayloadRequest(
        secret_id=secret_id
    ))

    for entry in response.entries:
        res[entry.key] = entry.text_value
    return res
