import paho.mqtt.client as mqtt
import sys
import threading
from enum import IntEnum

MQTT_SERVER = 'mqtt.cloud.yandex.net'
MQTT_PORT = 8883
ROOTCA_PATH = 'rootCA.crt'

DEVICE_ID = "<insert device id>"
DEVICE_PASSWORD = "<insert device password>"
REGISTRY_ID = "<insert registry id"
REGISTRY_PASSWORD = "<insert registry password>"

REGISTRY_COMMANDS = "$registries/" + REGISTRY_ID + "/commands"
REGISTRY_EVENTS = "$registries/" + REGISTRY_ID + "/events"

# False means use certificates
USE_DEVICE_LOGIN_PASSWORD = False
USE_REGISTRY_LOGIN_PASSWORD = False


class Qos(IntEnum):
    AT_MOST_ONCE = 0
    AT_LEAST_ONCE = 1


class YaClient:

    def __init__(self, client_id):
        self.received = threading.Event()
        self.qos = Qos.AT_LEAST_ONCE
        self.client = mqtt.Client(client_id)
        self.client.user_data_set(self.received)
        self.client.on_message = self.on_message

    def start_with_cert(self, cert_file, key_file):
        self.client.tls_set(ROOTCA_PATH, cert_file, key_file)
        self.client.connect(MQTT_SERVER, MQTT_PORT, 60)
        self.client.loop_start()

    def start_with_login(self, login, password):
        self.client.tls_set(ROOTCA_PATH)
        self.client.username_pw_set(login, password)
        self.client.connect(MQTT_SERVER, MQTT_PORT, 60)
        self.client.loop_start()

    def disconnect(self):
        self.client.loop_stop()

    @staticmethod
    def on_message(client, userdata, message):
        print("Received message '" + str(message.payload) + "' on topic '"
              + message.topic + "' with QoS " + str(message.qos))
        userdata.set()

    def publish(self, topic, payload):
        rc = self.client.publish(topic, payload, self.qos)
        rc.wait_for_publish()
        return rc.rc

    def subscribe(self, topic):
        return self.client.subscribe(topic, self.qos)

    def wait_subscribed_data(self):
        self.received.wait()
        self.received.clear()


def main():
    dev = YaClient('Test_Device_Client')
    reg = YaClient('Test_Registry_Client')

    if USE_DEVICE_LOGIN_PASSWORD:
        dev.start_with_login(DEVICE_ID, DEVICE_PASSWORD)
    else:
        dev.start_with_cert('device/dev.crt', 'device/dev.key')

    if USE_REGISTRY_LOGIN_PASSWORD:
        reg.start_with_login(REGISTRY_ID, REGISTRY_PASSWORD)
    else:
        reg.start_with_cert('reg.crt', 'reg.key')

    res, _ = dev.subscribe(REGISTRY_COMMANDS)
    if res != mqtt.MQTT_ERR_SUCCESS:
        sys.exit("Can't subscribe on [ " + REGISTRY_COMMANDS + " ]")

    res, _ = reg.subscribe(REGISTRY_EVENTS)
    if res != mqtt.MQTT_ERR_SUCCESS:
        sys.exit("Can't subscribe on [ " + REGISTRY_EVENTS + " ]")

    res = reg.publish(REGISTRY_COMMANDS, "reg commands")
    if res != mqtt.MQTT_ERR_SUCCESS:
        sys.exit("Can't publish [ " + REGISTRY_COMMANDS + " ]")

    res = dev.publish(REGISTRY_EVENTS, "reg events")
    if res != mqtt.MQTT_ERR_SUCCESS:
        sys.exit("Can't publish [ " + REGISTRY_EVENTS + " ]")

    dev.wait_subscribed_data()
    reg.wait_subscribed_data()

    dev.disconnect()
    reg.disconnect()


if __name__ == "__main__":
    main()
