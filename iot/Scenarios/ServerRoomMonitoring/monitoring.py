import datetime
import logging
import requests
import os
import json
import base64

METRICS_PUSH_URL = 'https://monitoring.api.cloud.yandex.net/monitoring/v2/data/write'
METRICS_SERVICE = 'custom'

logger = logging.getLogger()
logger.setLevel(logging.INFO)

verboseLogging = eval(os.environ['VERBOSE_LOG']) ## Convert to bool

if  verboseLogging:
    logger.info('Loading my-function')

def pushMetrics(iamToken, msg):
    folderId = os.environ["METRICS_FOLDER_ID"]
    metrics = makeAllMetrics(msg)
    if verboseLogging:
        logger.info(f'Metrics request: {metrics}')
    resp = requests.post(
        METRICS_PUSH_URL,
        json=metrics,
        headers={"Authorization": "Bearer " + iamToken},
        params={"folderId": folderId, "service": METRICS_SERVICE}
    )
    if verboseLogging:
        logger.info(f'Metrics response: {resp}')
        logger.info(f'Metrics response.content: {resp.content}')

"""
Input Json format is:
{
    "DeviceId":"0e3ce1d0-1504-4325-972f-55c961319814",
    "TimeStamp":"2020-05-21T22:57:15Z",
    "Values":[
        {"Type":"Float","Name":"Humidity","Value":"25.49"},
        {"Type":"Float","Name":"Temperature","Value":"80.53"},
        {"Type":"Bool","Name":"Water sensor","Value":"False"},
        {"Type":"Bool","Name":"Smoke sensor","Value":"False"},
        {"Type":"Bool","Name":"Room door sensor","Value":"False"},
        {"Type":"Bool","Name":"Rack door sensor","Value":"False"}
        ]
}
"""
def makeAllMetrics(msg):
    metrics = [
        makeFloatMetric(msg["Values"][0]["Name"], msg["Values"][0]["Value"]),
        makeFloatMetric(msg["Values"][1]["Name"], msg["Values"][1]["Value"]),
        makeBoolMetric(msg["Values"][2]["Name"], msg["Values"][2]["Value"]),
        makeBoolMetric(msg["Values"][3]["Name"], msg["Values"][3]["Value"]),
        makeBoolMetric(msg["Values"][4]["Name"], msg["Values"][4]["Value"]),
        makeBoolMetric(msg["Values"][5]["Name"], msg["Values"][5]["Value"]),
    ]
    ts = msg["TimeStamp"]
    return {
        "ts": ts,
        "labels": {
            "device_id": msg["DeviceId"],
        },
        "metrics": metrics
    }

def makeFloatMetric(name, value):
    return {
        "name": name,
        "type": "DGAUGE",
        "value": float(value),
    }

def makeBoolMetric(name, value):
    return {
        "name": name,
        "type": "IGAUGE",
        "value": int(value == "True"),
    }

"""
    Entry-point for Serverless Function.
    :param event: IoT message payload.
    :param context: information about current execution context.
    :return: sucessfull response statusCode: 200
"""
def msgHandler(event, context):
    statusCode = 500  ## Error response by default

    if verboseLogging:
        logger.info(event)
        logger.info(context)

    msg_payload = json.dumps(event["messages"][0])
    json_msg = json.loads(msg_payload)
    event_payload = base64.b64decode(json_msg["details"]["payload"])

    if verboseLogging:
        logger.info(f'Event: {event_payload}')

    payload_json = json.loads(event_payload)

    iam_token = context.token["access_token"]
    pushMetrics(iam_token, payload_json)

    statusCode = 200
    
    return {
        'statusCode': statusCode,
        'headers': {
            'Content-Type': 'text/plain'
        },
        'isBase64Encoded': False
    }



"""
Data for test:

{
    "messages": [
        {
            "event_metadata": {
                "event_id": "160d239876d9714800",
                "event_type": "yandex.cloud.events.iot.IoTMessage",
                "created_at": "2020-05-08T19:16:21.267616072Z",
                "folder_id": "b112345678910"
            },
            "details": {
                "registry_id": "are1234567890",
                "device_id": "are0987654321",
                "mqtt_topic": "$devices/are0987654321/events",
                "payload": "eyJWYWx1ZXMiOiBbeyJUeXBlIjogIkZsb2F0IiwgIlZhbHVlIjogIjI1Ljc0IiwgIk5hbWUiOiAiSHVtaWRpdHkifSwgeyJUeXBlIjogIkZsb2F0IiwgIlZhbHVlIjogIjgwLjY1IiwgIk5hbWUiOiAiVGVtcGVyYXR1cmUifSwgeyJUeXBlIjogIkJvb2wiLCAiVmFsdWUiOiAiRmFsc2UiLCAiTmFtZSI6ICJXYXRlciBzZW5zb3IifSwgeyJUeXBlIjogIkJvb2wiLCAiVmFsdWUiOiAiRmFsc2UiLCAiTmFtZSI6ICJTbW9rZSBzZW5zb3IifSwgeyJUeXBlIjogIkJvb2wiLCAiVmFsdWUiOiAiRmFsc2UiLCAiTmFtZSI6ICJSb29tIGRvb3Igc2Vuc29yIn0sIHsiVHlwZSI6ICJCb29sIiwgIlZhbHVlIjogIkZhbHNlIiwgIk5hbWUiOiAiUmFjayBkb29yIHNlbnNvciJ9XSwgIlRpbWVTdGFtcCI6ICIyMDIwLTA1LTIxVDIzOjEwOjE2WiIsICJEZXZpY2VJZCI6ICIwZTNjZTFkMC0xNTA0LTQzMjUtOTcyZi01NWM5NjEzMTk4MTQifQ=="
            }
        }
    ]
}
"""
