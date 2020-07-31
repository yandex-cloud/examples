import os
import logging
import psycopg2
import psycopg2.errors
import datetime as dt
import json
import base64
import random

logger = logging.getLogger()
logger.setLevel(logging.INFO)

verboseLogging = eval(os.environ['VERBOSE_LOG']) ## Convert to bool

if  verboseLogging:
    logger.info('Loading msgHandler function')

def getConnString():
    """
    Extract env variables to connect to DB and return a db string
    Raise an error if the env variables are not set
    :return: string
    """
    db_hostname = os.environ['DB_HOSTNAME']
    db_port =  os.environ['DB_PORT']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_password = os.environ['DB_PASSWORD']
    db_connection_string = f"host='{db_hostname}' port='{db_port}'  dbname='{db_name}' user='{db_user}' password='{db_password}'  sslmode='require'"
    return db_connection_string

""" Data example:

    "DeviceId":"are1234567qwerty",
    "TimeStamp":"2020-06-09T20:41:45Z",
    "Values":[
        {"Type":"Bool","Name":"Service door sensor","Value":"False"},
        {"Type":"Float","Name":"Power Voltage","Value":"24.94"},
        {"Type":"Float","Name":"Temperature","Value":"10.48"},
        {"Type":"Float","Name":"Cash drawer fullness","Value":"67.89"},
        {"Items":[
            {"Type":"Float", "Id":"1","Name":"Item 1","Fullness":"50.65"},
            {"Type":"Float", "Id":"2","Name":"Item 2","Fullness":"80.97"},
            {"Type":"Float", "Id":"3","Name":"Item 3","Fullness":"30.33"},
            {"Type":"Float", "Id":"4","Name":"Item 4","Fullness":"15.15"}
        ]}
        ]
"""

def makeDataInsertStatement(event_id, payload_json, table_name):

    event = json.loads(payload_json)
    logger.info(event)
    insert=  f"""INSERT INTO {table_name} (event_id, device_id, event_datetime,
                 service_door, power_voltage, temperature, cash_drawer, item1_fullness, item2_fullness, item3_fullness, item4_fullness) 
                 VALUES('{event_id}','{event['DeviceId']}', '{event['TimeStamp']}',
                 {event['Values'][0]['Value']}, {event['Values'][1]['Value']}, {event['Values'][2]['Value']}, {event['Values'][3]['Value']},
                 {event['Values'][4]['Items'][0]['Fullness']}, {event['Values'][4]['Items'][1]['Fullness']}, {event['Values'][4]['Items'][2]['Fullness']}, {event['Values'][4]['Items'][3]['Fullness']})
                 """

    return insert

def makePositionQueryStatement(event_id, payload_json, table_name, latitude, longitude):

    event = json.loads(payload_json)
    logger.info(event)
    query = f"""INSERT INTO {table_name} 
                (device_id,latitude,longitude)
                VALUES('{event['DeviceId']}', {latitude}, {longitude})
                ON CONFLICT DO NOTHING
                """
    return query

def makeCreateDataTableStatement(table_name):

    statement = f"""CREATE TABLE public.{table_name} (
    event_id text not null,
    device_id text not null,
    event_datetime timestamp not null,
    service_door bool null,
    power_voltage float null,
    temperature float null,
    cash_drawer float null,
    item1_fullness float null,
    item2_fullness float null,
    item3_fullness float null,
    item4_fullness float null
    );"""
    return statement
    
def makeCreatePositionTableStatement(table_name):

    statement = f"""CREATE TABLE public.{table_name} (
    device_id text not null PRIMARY KEY,
    latitude float,
    longitude float
    );"""
    return statement

"""
    Entry-point for Serverless Function.
    :param event: IoT message payload.
    :param context: information about current execution context.
    :return: sucessfull response statusCode: 200
"""
def msgHandler(event, context):
    statusCode = 500 ## Error response by default
    if  verboseLogging:
        logger.info(event)
        logger.info(context)

    connection_string = getConnString()
    
    if  verboseLogging:
        logger.info(f'Connecting: {connection_string}')

    conn = psycopg2.connect(connection_string)

    cursor = conn.cursor()
    msg_payload = json.dumps(event["messages"][0])
    json_msg = json.loads(msg_payload)
    event_payload = base64.b64decode(json_msg["details"]["payload"])

    if  verboseLogging:     
        logger.info(f'Event: {event_payload}')

    event_id = json_msg["event_metadata"]["event_id"]


    ## Insert position data

    latitude = 55.733113 + random.uniform(0, 0.001)
    longitude = 37.586606 + random.uniform(0, 0.001)
    table_name = 'iot_position'
    sql = makePositionQueryStatement(event_id, event_payload, table_name, latitude, longitude) ## let's name table 'iot_position'

    if  verboseLogging:     
        logger.info(f'Exec: {sql}')

    try:
        cursor.execute(sql)
    except psycopg2.errors.UndefinedTable as error: ## table not exist - create and repeate insert
        conn.rollback()
        logger.error( error)        
        createTable = makeCreatePositionTableStatement(table_name)
        cursor.execute(createTable)
        conn.commit()
        cursor.execute(sql)
    except Exception as error:
        logger.error( error)

    ## Insert device data

    table_name = 'iot_events'
    sql = makeDataInsertStatement(event_id, event_payload, table_name) ## let's name table 'iot_events'

    if  verboseLogging:     
        logger.info(f'Exec: {sql}')

    try:
        cursor.execute(sql)
        statusCode = 200
    except psycopg2.errors.UndefinedTable as error: ## table not exist - create and repeate insert
        conn.rollback()
        logger.error( error)        
        createTable = makeCreateDataTableStatement(table_name)
        cursor.execute(createTable)
        conn.commit()
        cursor.execute(sql)
        statusCode = 200
    except Exception as error:
        logger.error( error)
    conn.commit() # <- We MUST commit to reflect the inserted data
    cursor.close()
    conn.close()

    

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
                "payload": "ewogICAgICAgICAgICAiRGV2aWNlSWQiOiJhcmU1NzBrZTA1N29pcjg1bDlmciIsCiAgICAgICAgICAgICJUaW1lU3RhbXAiOiIyMDIwLTA2LTExVDExOjA3OjIwWiIsCiAgICAgICAgICAgICJWYWx1ZXMiOlsKICAgICAgICAgICAgICAgIHsiVHlwZSI6IkJvb2wiLCJOYW1lIjoiU2VydmljZSBkb29yIHNlbnNvciIsIlZhbHVlIjoiRmFsc2UifSwKICAgICAgICAgICAgICAgIHsiVHlwZSI6IkZsb2F0IiwiTmFtZSI6IlBvd2VyIFZvbHRhZ2UiLCJWYWx1ZSI6IjI1LjA2In0sCiAgICAgICAgICAgICAgICB7IlR5cGUiOiJGbG9hdCIsIk5hbWUiOiJUZW1wZXJhdHVyZSIsIlZhbHVlIjoiMTEuMjEifSwKICAgICAgICAgICAgICAgIHsiVHlwZSI6IkZsb2F0IiwiTmFtZSI6IkNhc2ggZHJhd2VyIGZ1bGxuZXNzIiwiVmFsdWUiOiI2Ny44OSJ9LAogICAgICAgICAgICAgICAgeyJJdGVtcyI6WwogICAgICAgICAgICAgICAgICAgIHsiVHlwZSI6IkZsb2F0IiwgIklkIjoiMSIsIk5hbWUiOiJJdGVtIDEiLCJGdWxsbmVzcyI6IjUwLjY1In0sCiAgICAgICAgICAgICAgICAgICAgeyJUeXBlIjoiRmxvYXQiLCAiSWQiOiIyIiwiTmFtZSI6Ikl0ZW0gMiIsIkZ1bGxuZXNzIjoiODAuOTcifSwKICAgICAgICAgICAgICAgICAgICB7IlR5cGUiOiJGbG9hdCIsICJJZCI6IjMiLCJOYW1lIjoiSXRlbSAzIiwiRnVsbG5lc3MiOiIzMC4zMyJ9LAogICAgICAgICAgICAgICAgICAgIHsiVHlwZSI6IkZsb2F0IiwgIklkIjoiNCIsIk5hbWUiOiJJdGVtIDQiLCJGdWxsbmVzcyI6IjE1LjE1In0KICAgICAgICAgICAgICAgIF19CiAgICAgICAgICAgICAgICBdCiAgICAgICAgICAgIH0="
            }
        }
    ]
}
"""
