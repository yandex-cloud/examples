#include <mqtt/message.h>
#include "client_queue.h"

namespace yandex {

    void client_queue::pop(std::pair<std::string, mqtt::message> &val) {
        std::unique_lock<std::mutex> lock(mu);
        while (q.empty()) {
            wait.wait(lock);
        }
        val = q.front();
        q.pop();
    }

    void client_queue::push(std::pair<std::string, mqtt::message> msg) {
        {
            std::unique_lock<std::mutex> lock(mu);
            q.push(msg);
        }
        wait.notify_one();
    }

}