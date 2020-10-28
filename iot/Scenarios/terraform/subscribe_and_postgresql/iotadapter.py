import os
import logging
import psycopg2
import psycopg2.errors
import datetime as dt
import json
import base64

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

"""
Imput Json format is:
{
    "DeviceId":"7d972e16-2cc7-49aa-a3fb-153be9b2e04f",
    "TimeStamp":"2020-05-19T18:41:37.145+03:00",
    "Values":[
        {"Type":"Float","Name":"Humidity","Value":"90.22961"},
        {"Type":"Float","Name":"CarbonDioxide","Value":"125.06672"},
        {"Type":"Float","Name":"Pressure","Value":"32.808365"},
        {"Type":"Float","Name":"Temperature","Value":"31.049744"}
        ]
}
"""
def makeInsertStatement(event_id, payload_json, table_name):
    if  verboseLogging:
        logger.info(f'payload_jsn: {payload_json}')


    event = json.loads(payload_json)
    if  verboseLogging:
        logger.info(event)
    insert=  f"""INSERT INTO {table_name} (event_id, device_id, event_datetime,
                 humidity, carbon_dioxide, pressure, temperature) 
                 VALUES('{event_id}','{event['DeviceId']}', '{event['TimeStamp']}',
                 {event['Values'][0]['Value']}, {event['Values'][1]['Value']}, {event['Values'][2]['Value']}, {event['Values'][3]['Value']})"""

    return insert

def makeCreateTableStatement(table_name):
    statement = f"""CREATE TABLE public.{table_name} (
    event_id varchar(24) not null,
    device_id varchar(50) not null,
    event_datetime timestamptz not null,
    humidity float8 null,
    carbon_dioxide float8 null,
    pressure float8 null,
    temperature float8 null
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
    first_msg = event["messages"][0]
    msg_payload = json.dumps(first_msg)
    json_msg = json.loads(msg_payload)

    if  verboseLogging:     
        logger.info(f'Event: {json_msg["details"]}')

    table_name = 'iot_events'

    evid = first_msg.get('event_metadata', {})['event_id']
    payload = first_msg.get('details', {})['payload']
    payload_str=base64.decodestring(payload.encode())

    sql = makeInsertStatement(evid, payload_str, table_name)

    if  verboseLogging:
        logger.info(f'Exec: {sql}')

    try:
        cursor.execute(sql)
        statusCode = 200
    except psycopg2.errors.UndefinedTable as error: ## table not exist - create and repeate insert
        conn.rollback()
        logger.error( error)        
        createTable = makeCreateTableStatement(table_name)
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
    
''''
#### PAYLOAD EXAMPLE FOR LOCAL DEBUGGING ### 
msgHandler("""{
	"messages": [
        {
            "event_metadata": {
                "event_id": "160d239876d9714800",
                "event_type": "yandex.cloud.events.iot.IoTMessage",
                "created_at": "2020-05-08T19:16:21.267616072Z",
                "folder_id": "is1sample2idfolder"
            },
            "details": {
                "registry_id": "is1sample2id3registry",
                "device_id": "is1sample2id3device",
                "mqtt_topic": "$devices/is1sample2id3device/events",
                "payload": "eyJWYWx1ZXMiOiBbeyJWYWx1ZSI6ICI5MC4yMjk2MSIsICJUeXBlIjogIkZsb2F0IiwgIk5hbWUiOiAiSHVtaWRpdHkifSwgeyJWYWx1ZSI6ICIxMjUuMDY2NzIiLCAiVHlwZSI6ICJGbG9hdCIsICJOYW1lIjogIkNhcmJvbkRpb3hpZGUifSwgeyJWYWx1ZSI6ICIzMi44MDgzNjUiLCAiVHlwZSI6ICJGbG9hdCIsICJOYW1lIjogIlByZXNzdXJlIn0sIHsiVmFsdWUiOiAiMzEuMDQ5NzQ0IiwgIlR5cGUiOiAiRmxvYXQiLCAiTmFtZSI6ICJUZW1wZXJhdHVyZSJ9XSwgIkRldmljZUlkIjogIjdkOTcyZTE2LTJjYzctNDlhYS1hM2ZiLTE1M2JlOWIyZTA0ZiIsICJUaW1lU3RhbXAiOiAiMjAyMC0wNS0xOVQxODo0MTozNy4xNDUrMDM6MDAifQ=="
            }
        }
    ]
}""", None)
'''
    
