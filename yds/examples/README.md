# Example of how to send Yandex Data Streams messages by raw HTTP

Sample project for send messages by row HTTP.

# Yandex Services
* [Yandex Data Stream](https://cloud.yandex.ru/services/yds)
* [Yandex Database](https://cloud.yandex.ru/services/ydb)

# Prepare services

1. Create _Yandex Data Streams_ stream and save full stream name
2. Create static credentials with `yds.writer` role

# Send message to stream
1. Set environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` to static credentials
2. Fill script arguments 
   - `--full-stream-name` with full stream name like /ru-central1/b2g6ad43m6he1ooql98r/etn01eh5rn074ncm9cbb/your_stream_name
   - `--message` with message to send to Yandex Data Streams
3. Run the script

