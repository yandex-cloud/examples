#ifndef __yandex_ya_client_h
#define __yandex_ya_client_h

#include <iostream>
#include <optional>
#include <future>
#include "mqtt/async_client.h"
#include "client_queue.h"

namespace yandex {

const std::string BROKER_URL = "ssl://mqtt.cloud.yandex.net:8883";
const std::string ROOT_CA = "../rootCA.crt";

class ya_client : public mqtt::callback {
public:
    explicit ya_client(std::string client_id);

    ~ya_client();

    void startWithCerts(std::string certPath, std::string keyPath);

    void startWithLogin(std::string login, std::string password);

    std::future<mqtt::ReasonCode> subscribe(std::string topic);

    std::future<mqtt::ReasonCode> publish(std::string topic, const void* payload, size_t sz);

    std::future<mqtt::ReasonCode> publish(std::string topic, std::string payload);

    mqtt::message get_received_msg();

    std::string get_client_id();

    void set_target(client_queue *queue);

    void disconnect();

    void message_arrived(mqtt::const_message_ptr msg) override;

private:
    std::unique_ptr<mqtt::async_client> client;
    mqtt::connect_options connOpts;
    client_queue *queue;
    std::optional<mqtt::message> received_msg;
    const int qos = 1;
};

}

#endif		// __yandex_ya_client_h
