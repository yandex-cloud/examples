package com.example

import com.justai.jaicf.channel.yandexalice.model.AliceEvent
import com.justai.jaicf.model.scenario.Scenario

/**
 * Этот файл содержит сценарий вашего навыка.
 * Читайте подробнее о том, как создавать диалоговые сценарии на https://github.com/just-ai/jaicf-kotlin/wiki
 */
object MainScenario: Scenario() {
    init {

        /**
         * Стартовое сообщение, когда пользователь запускает ваш навык
         */
        state("start") {
            activators {
                event(AliceEvent.START)
            }

            action {
                reactions.say("Привет! Скажи мне что-нибудь, а я повторю")
            }
        }

        /**
         * Любое другое сообщение навык просто будет возвращать обратно пользователю
         */
        fallback {
            reactions.say(request.input)
        }
    }
}