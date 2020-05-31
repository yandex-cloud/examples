cmake_minimum_required(VERSION 3.15)

set(CMAKE_CXX_STANDARD 17)

project(iotExample)

add_executable(iotExample main.cpp ya_client.cpp ya_client.h client_queue.cpp client_queue.h)

SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")

target_link_libraries(iotExample -lpaho-mqttpp3)
target_link_libraries(iotExample -lpaho-mqtt3as)
