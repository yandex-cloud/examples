package com.example

import com.justai.jaicf.BotEngine
import com.justai.jaicf.channel.yandexalice.AliceChannel

val skill = BotEngine(
    model = MainScenario.model
)

val channel = AliceChannel(
    botApi = skill,
    useDataStorage = true,
    oauthToken = System.getenv("OAUTH_TOKEN")
)