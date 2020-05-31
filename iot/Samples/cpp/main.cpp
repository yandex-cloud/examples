#include <iostream>
#include "mqtt/async_client.h"
#include "ya_client.h"

const std::string DEVICE_ID = "<insert device id>";
const std::string DEVICE_PASSWORD = "<insert device password>";
const std::string REGISTRY_ID = "<insert registry id>";
const std::string REGISTRY_PASSWORD = "<insert registry password>";

const std::string REGISTRY_COMMANDS = "$registries/" + REGISTRY_ID + "/commands";
const std::string REGISTRY_EVENTS = "$registries/" + REGISTRY_ID + "/events";

// false means use certificates
const bool USE_DEVICE_LOGIN_PASSWORD = true;
const bool USE_REGISTRY_LOGIN_PASSWORD = false;

int main() {
    yandex::client_queue queue;
    yandex::ya_client dev("Test_device_Client");
    yandex::ya_client reg("Test_registry_Client");
    dev.set_target(&queue);
    reg.set_target(&queue);

    if (USE_DEVICE_LOGIN_PASSWORD) {
        dev.startWithLogin(DEVICE_ID, DEVICE_PASSWORD);
    } else {
        dev.startWithCerts("../device/dev.crt", "../device/dev.key");
    }
    if (USE_REGISTRY_LOGIN_PASSWORD) {
        reg.startWithLogin(REGISTRY_ID, REGISTRY_PASSWORD);
    } else {
        reg.startWithCerts("../reg.crt", "../reg.key");
    }

    auto dev_sub = dev.subscribe(REGISTRY_COMMANDS);
    auto reg_sub = reg.subscribe(REGISTRY_EVENTS);

    dev_sub.wait();
    reg_sub.wait();
    mqtt::ReasonCode rc;
    if ((rc = dev_sub.get()) != mqtt::SUCCESS) {
        std::cout << rc << ": Device can't subscribe on [ " << REGISTRY_COMMANDS << " ]";
        return 1;
    }
    if ((rc = reg_sub.get()) != mqtt::SUCCESS) {
        std::cout << rc << ": Registry can't subscribe on [ " << REGISTRY_EVENTS << " ]";
        return 1;
    }

    auto reg_pub = reg.publish(REGISTRY_COMMANDS, "publish registry commands");
    auto dev_pub = dev.publish(REGISTRY_EVENTS, "publish registry events");

    reg_pub.wait();
    dev_pub.wait();
    if ((rc = reg_pub.get()) != mqtt::SUCCESS) {
        std::cout << rc << ": Registry can't publish [ " << REGISTRY_COMMANDS << " ]";
        return 1;
    }
    if ((rc = dev_pub.get()) != mqtt::SUCCESS) {
        std::cout << rc << ": Device can't publish [ " << REGISTRY_EVENTS << " ]";
        return 1;
    }

    std::pair<std::string, mqtt::message> res;
    queue.pop(res);
    std::cout << res.first << " received [" << res.second.to_string() << "]" << std::endl;
    queue.pop(res);
    std::cout << res.first << " received [" << res.second.to_string() << "]" << std::endl;
}
