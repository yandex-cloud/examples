import argparse
import json
from typing import Dict

import grpc

from yandex.cloud.speechsense.v1 import talk_service_pb2
from yandex.cloud.speechsense.v1 import talk_service_pb2_grpc
from yandex.cloud.speechsense.v1 import audio_pb2


def container_audio(audio_type: str) -> audio_pb2.ContainerAudio:
    if audio_type == 'wav':
        return audio_pb2.ContainerAudio(
            container_audio_type=audio_pb2.ContainerAudio.ContainerAudioType.CONTAINER_AUDIO_TYPE_WAV
        )
    elif audio_type == 'ogg':
        return audio_pb2.ContainerAudio(
            container_audio_type=audio_pb2.ContainerAudio.ContainerAudioType.CONTAINER_AUDIO_TYPE_OGG_OPUS
        )
    elif audio_type == 'mp3':
        return audio_pb2.ContainerAudio(
            container_audio_type=audio_pb2.ContainerAudio.ContainerAudioType.CONTAINER_AUDIO_TYPE_MP3
        )


def upload_talk(endpoint: str, connection_id: str, metadata: Dict[str, str], token: str, audio_bytes: bytes, audio_type: str):
    # Установите соединение с сервером
    credentials = grpc.ssl_channel_credentials()
    channel = grpc.secure_channel(endpoint, credentials)
    talk_service_stub = talk_service_pb2_grpc.TalkServiceStub(channel)

    # Сформируйте запрос на загрузку диалога
    request = talk_service_pb2.UploadTalkRequest(

        metadata=talk_service_pb2.TalkMetadata(
            connection_id=connection_id,
            fields=metadata
        ),
        audio=audio_pb2.AudioRequest(
            audio_metadata=audio_pb2.AudioMetadata(
                container_audio=container_audio(audio_type)
            ),
            audio_data=audio_pb2.AudioChunk(data=audio_bytes)
        )
    )

    # Обработайте ответ сервера
    response = talk_service_stub.Upload(request, metadata=(
        ('authorization', token),
    ))
    print(f'Talk id: {response.talk_id}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument('--endpoint', required=False, help='API Endpoint', type=str, default='api.talk-analytics.yandexcloud.net:443')
    parser.add_argument('--token', required=True, help='IAM token', type=str)
    parser.add_argument('--token-type', required=False, help='Token type', choices=['iam-token', 'api-key'], default='iam-token', type=str)
    parser.add_argument('--connection-id', required=True, help='Connection Id', type=str)
    parser.add_argument('--audio-path', required=True, help='Audio file path', type=str)
    parser.add_argument('--audio-type', required=False, help='Audio file type', choices=['wav', 'ogg', 'mp3'], type=str)
    parser.add_argument('--meta-path', required=False, help='Talk metadata json', type=str, default=None)
    args = parser.parse_args()

    required_keys = [
        "operator_name",
        "operator_id",
        "client_name",
        "client_id",
        "date_from",
        "date_to",
        "direction_outgoing"
    ]
    with open(args.meta_path, 'r') as fp:
        metadata = json.load(fp)
    for required_key in required_keys:
        if required_key not in metadata:
            raise ValueError(f"Metadata doesn't contain one of the reqiured keys: {required_key}.")

    if args.token_type == 'iam-token':
        token = f'Bearer {args.token}'
    elif args.token_type == 'api-key':
        token = f'Api-Key {args.token}'
    else:
        raise Exception(f'Unknown token type {args.token_type}')

    if args.audio_type is None:
        file_extension = args.audio_path.split('.')[-1]
        if file_extension not in ['wav', 'ogg', 'mp3']:
            raise ValueError(f"Unknown file extension: {file_extension}. Specify the --audio-type argument.")
        audio_type = file_extension
    else:
        audio_type = args.audio_type

    with open(args.audio_path, 'rb') as fp:
        audio_bytes = fp.read()

    upload_talk(args.endpoint, args.connection_id, metadata, token, audio_bytes, audio_type)
