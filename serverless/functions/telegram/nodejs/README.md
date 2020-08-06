## Yandex Cloud Functions ❤️ Telegram

This directory contains an example Telegram bot built with a popular Telegram bot framework [Telegraf](https://github.com/telegraf/telegraf).

### Create Telegram bot

There are a lot of great tutorials about creating Telegram bots, but [official one](https://core.telegram.org/bots/#creating-a-new-bot) is comprehensive.

After completing this step you will get `BOT_TOKEN`, which you should keep in secret.

### Create Yandex Cloud Function

You can use both the web console and command-line Tool to create or update Function. We will use CLI:

    yc serverless function create --name my-telegram-bot

Wait a bit and head next to Function deployment, but before write down Function ID, we will use it later. To deploy new version you should navigate to this directory, and then use `function version create`:

    yc serverless function version create  \
      --function-name my-telegram-bot      \
      --memory 256m                        \
      --execution-timeout 5s               \
      --runtime nodejs12-preview           \
      --entrypoint index.handler           \
      --source-path .                      \
      --environment BOT_TOKEN=<YOUR_TOKEN>

And the last step will be granting unauthorized access to allow Telegram to invoke this function:

    yc serverless function allow-unauthenticated-invoke my-telegram-bot

### Set-up Web Hook

Telegram provides full [documentation](https://core.telegram.org/bots/api#setwebhook) on API, but will use only `setWebhook` method:

    curl -F "url=https://functions.yandexcloud.net/<FUNCTION_ID>" \
      https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook

### Test your bot

At this moment your bot should work and will reply to every message you sent. Just find it and start chatting!
