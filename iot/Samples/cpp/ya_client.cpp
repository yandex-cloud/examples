#include "ya_client.h"

namespace yandex {

    ya_client::ya_client(std::string client_id) : client(
            std::make_unique<mqtt::async_client>(BROKER_URL, client_id)), received_msg() {
        client->set_callback(*this);
        connOpts.set_connect_timeout(60);
        connOpts.set_keep_alive_interval(60);
        connOpts.set_clean_session(true);
    }

    ya_client::~ya_client() {
        if (client->is_connected()) {
            this->disconnect();
        }
    }

    void ya_client::startWithCerts(std::string certPath, std::string keyPath) {
        mqtt::ssl_options sslOpts;
        sslOpts.set_trust_store(ROOT_CA);
        sslOpts.set_key_store(certPath);
        sslOpts.set_private_key(keyPath);
        connOpts.set_ssl(sslOpts);
        client->connect(connOpts)->wait();
    }

    void ya_client::startWithLogin(std::string login, std::string password) {
        mqtt::ssl_options sslOpts;
        sslOpts.set_trust_store(ROOT_CA);
        connOpts.set_ssl(sslOpts);
        connOpts.set_user_name(login);
        connOpts.set_password(password);
        client->connect(connOpts)->wait();
    }

    std::future<mqtt::ReasonCode> ya_client::subscribe(std::string topic) {
        auto subtok = client->subscribe(topic, qos);
        return std::async([](const mqtt::token_ptr &token) {
            token->wait();
            return token->get_reason_code();
        }, subtok);
    }

    std::future<mqtt::ReasonCode> ya_client::publish(std::string topic, const void *payload, size_t sz) {
        auto pubtok = client->publish(topic, payload, sz, qos, false);
        return std::async([](const mqtt::delivery_token_ptr &token) {
            token->wait();
            return token->get_reason_code();
        }, pubtok);
    }

    std::future<mqtt::ReasonCode> ya_client::publish(std::string topic, std::string payload) {
        auto pubtok = client->publish(topic, payload, qos, false);
        return std::async([](const mqtt::delivery_token_ptr &token) {
            token->wait();
            return token->get_reason_code();
        }, pubtok);
    }

    mqtt::message ya_client::get_received_msg() {
        return received_msg.value();
    }

    void ya_client::disconnect() {
        client->disconnect()->wait();
    }

    void ya_client::message_arrived(mqtt::const_message_ptr msg) {
        received_msg.emplace(*msg);
        if (queue) {
            queue->push({client->get_client_id(), received_msg.value()});
        }
    }

    void ya_client::set_target(client_queue *q) {
        queue = q;
    }

    std::string ya_client::get_client_id() {
        return client->get_client_id();
    }

}