## Скрипт для загрузки данных в SpeechSense

Ниже рассмотрен пример загрузки диалога в SpeechSense. В примере заданы параметры:

* Формат аудио -- WAV
     
     Поддерживаемые форматы:

     * wav
     * mp3
     * ogg
     * При изменении сообщения возможно отправить 16-bit PCM

* Метаданные диалога из [metadata_example.json](metadata_example.json)

Скрипт с загрузкой аудио одним сообщением: [upload_grpc.py](upload_grpc.py)

Скрипт с загрузкой аудио через стриминг чанками по 1Мб: [upload_grpc_streaming.py](upload_grpc_streaming.py)

### Начало работы

Для работы с API нужен пакет `grpcio-tools`.

Аутентификация происходит с помощью [IAM-токена](https://cloud.yandex.ru/docs/iam/concepts/authorization/iam-token), либо с помощью [API-ключа](https://cloud.yandex.ru/docs/iam/concepts/authorization/api-key).

Чтобы реализовать пример из этого раздела:

   * Установите пакет grpcio-tools с помощью менеджера пакетов pip:

        `pip install grpcio-tools`

   * В текущей папке выполните скрипт:

        ```
        cd ..
        python3 -m grpc_tools.protoc -I . \
            --python_out=./upload-data/ \
            --grpc_python_out=./upload-data/ \
            yandex/cloud/speechsense/v1/talk_service.proto \
            yandex/cloud/speechsense/v1/audio.proto
        cd upload_data
        ```

   * Задайте [IAM-токен](https://cloud.yandex.ru/docs/iam/concepts/authorization/iam-token):
    
        ```
        export IAM_TOKEN=<IAM-токен>
        ```


   * Запустите скрипт [upload_grpc.py](upload_grpc.py) или [upload_grpc_streaming.py](upload_grpc_streaming.py), передав нужные параметры:
    
        ```
        python3 upload_grpc.py \
            --audio-path audio.wav \
            --meta-path metadata-example.json \
            --connection-id 2 \
            --token-type iam-token \
            --token ${IAM_TOKEN}
        ```

        Здесь:

        * `audio-path` -- путь до файла с аудио диалога.
        * `audio-type` -- тип контейнера для аудио. Если не передан, будет попытка интерпретировать расширение файла ка тип контейнера.
        * `meta-path` -- путь до файла с метаданными диалога.
        
            Метаданные должны содержать по крайней мере следующие обязательные поля:
                
            *  `operator_name` -- имя оператора.
            * `operator_id` -- Id оператора.
            * `client_name` -- имя клиента.
            * `client_id` -- Id клиента.
            * `date_from` -- дата и время начала диалога.
            * `date_to` -- дата и время окончания диалога.
            * `direction_outgoung` -- true/false в зависимости от направления звонка.

            Пример метаданных находится в файле [metadata_example.json](metadata_example.json).
