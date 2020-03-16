#ifndef __yandex_client_queue_h
#define __yandex_client_queue_h

#include <iostream>
#include <mutex>
#include <condition_variable>
#include <queue>

namespace yandex {

class client_queue {
public:
    void pop(std::pair<std::string, mqtt::message>& val);

    void push(std::pair<std::string, mqtt::message> msg);

private:
    std::queue<std::pair<std::string, mqtt::message>> q;
    std::mutex mu;
    std::condition_variable wait;
};

}

#endif		// __yandex_client_queue_h
