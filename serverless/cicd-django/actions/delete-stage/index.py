#!/usr/bin/env python3
import json
import logging
import os

import grpc
import yandexcloud
from yandex.cloud.serverless.apigateway.v1.apigateway_pb2 import (
    ApiGateway
)
from yandex.cloud.serverless.apigateway.v1.apigateway_service_pb2 import (
    ListApiGatewayRequest,
    ListApiGatewayResponse,
    DeleteApiGatewayRequest
)
from yandex.cloud.serverless.apigateway.v1.apigateway_service_pb2_grpc import ApiGatewayServiceStub
from yandex.cloud.serverless.containers.v1.container_service_pb2 import (
    ListContainersRequest,
    ListContainersResponse,
    DeleteContainerRequest
)
from yandex.cloud.serverless.containers.v1.container_service_pb2_grpc import ContainerServiceStub


def delete_apigw(sdk: yandexcloud.SDK, folder_id: str, name: str):
    apigw_service = sdk.client(ApiGatewayServiceStub)
    list_resp: ListApiGatewayResponse = apigw_service.List(ListApiGatewayRequest(
        folder_id=folder_id,
        filter='name="' + name + '"'
    ))
    gateways = list_resp.api_gateways
    if len(gateways) < 1:
        logging.info("No gateways found with name {} in folder {}".format(name, folder_id))
        return
    gateway: ApiGateway = gateways[0]
    logging.info("Deleting gateway id: {}, name: {}".format(gateway.id, gateway.name))
    delete_op = apigw_service.Delete(DeleteApiGatewayRequest(
        api_gateway_id=gateway.id
    ))
    sdk.wait_operation_and_get_result(delete_op)


def delete_container(sdk: yandexcloud.SDK, folder_id: str, name: str):
    channel = sdk._channels.channel("serverless-containers")
    container_service = ContainerServiceStub(channel)
    list_resp: ListContainersResponse = container_service.List(
        ListContainersRequest(
            folder_id=folder_id,
            filter='name="' + name + '"'
        )
    )
    containers = list_resp.containers
    if len(containers) < 1:
        logging.info("No container found with name {} in folder {}".format(name, folder_id))
        return
    container = containers[0]
    logging.info("Deleting container id: {}, name: {}".format(container.id, container.name))
    delete_op = container_service.Delete(DeleteContainerRequest(
        container_id=container.id
    ))
    sdk.wait_operation_and_get_result(delete_op)


def main():
    logging.basicConfig(level=logging.INFO)
    sa_key_str = os.environ.get("SA_KEY")
    sa_key = json.loads(sa_key_str)
    stage_name = os.environ.get("STAGE_NAME")
    folder_id = os.environ.get("FOLDER_ID")

    interceptor = yandexcloud.RetryInterceptor(max_retry_count=5, retriable_codes=[grpc.StatusCode.UNAVAILABLE])
    sdk = yandexcloud.SDK(interceptor=interceptor, service_account_key=sa_key)

    delete_apigw(sdk, folder_id, stage_name)
    delete_container(sdk, folder_id, stage_name)


if __name__ == '__main__':
    main()
