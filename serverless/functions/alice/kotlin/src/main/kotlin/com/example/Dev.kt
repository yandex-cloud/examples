package com.example

import com.justai.jaicf.channel.http.httpBotRouting
import io.ktor.routing.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*

/**
 * Используйте этот файл, чтобы тестировать ваш навык локально с использованием ngrok
 */
fun main() {
    embeddedServer(Netty, 8080) {
        routing {
            httpBotRouting("/" to channel)
        }
    }.start(wait = true)
}