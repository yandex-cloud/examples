# Example on how to send Yandex Data Streams messages by raw HTTP

Sample python3 project for send messages by raw HTTP. Based on [original example](https://stackoverflow.com/questions/51991401/how-to-implement-amazon-kinesis-putmedia-method-using-python).

# Yandex Services
* [Yandex Data Stream](https://cloud.yandex.ru/services/data-streams)
* [Yandex Database](https://cloud.yandex.ru/services/ydb)

# Prepare services

1. Create _Yandex Data Streams_ stream and save full stream name (full stream name includes stream name and containing database id)
2. Create static credentials with `yds.writer` role

# Send message to stream
1. Set environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` to static credentials
2. Fill script arguments 
   - `--full-stream-name` with full stream name like /ru-central1/b2g6ad43m6he1ooql98r/etn01eh5rn074ncm9cbb/your_stream_name
   - `--message` with message to send to Yandex Data Streams
3. Run the script

