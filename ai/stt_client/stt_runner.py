# brew install mediainfo | sudo apt-get install mediainfo
# pip3 install urllib3 google protobuf grpcio numpy

import os
import sys
import io
import time
import uuid
import re
import subprocess
import collections
import logging
import json
import copy
import argparse
import numpy
import datetime

from google.protobuf import text_format

import grpc

import yandex.cloud.ai.stt.v2.stt_service_pb2 as stt_service_pb2
import yandex.cloud.ai.stt.v2.stt_service_pb2_grpc as stt_service_pb2_grpc

GenDescriptor = collections.namedtuple('GenDescriptor',
                                       ['streaming_config', 'data', 'chunk_size', 'bytes_per_sec', 'adjust_time',
                                        'meta'])
EndpointDescriptor = collections.namedtuple('EndpointDescriptor', ['host', 'ssl'])

api_key = os.environ['YC_API_KEY']

script_dir_path = os.path.dirname(os.path.realpath(__file__))

general_log_extra = {'id': '#' * 36}

supported_format = 's16le'
supported_channels = 1

percentiles_to_calc = [50, 75, 90, 95, 99, 100]

request_logger = logging.getLogger('request_logger')


def extract_format_from_name(file_path):
    m = re.match('.*\.(alaw|mulaw|[fsu](?:8|16|32|64)(?:le|be)?)-ac([0-9]+)-ar([0-9]+)\.(?:pcm|raw)', file_path)
    return m.groups() if m else (None, None, None)


def get_opus_bytes_per_sec(file_path):
    res = subprocess.run(
        ['/bin/sh', '-c', 'mediainfo "%s" --Output=JSON | jq ".media.track[0].OverallBitRate"' % file_path],
        capture_output=True)
    return int(int(res.stdout.strip(b' "\n')) / 8)


def get_audio_info_from_mediainfo(file_path):
    res = subprocess.run(['/bin/sh', '-c', 'mediainfo "%s" --Output=JSON' % file_path], capture_output=True)
    info = json.loads(res.stdout)
    audio_info = None
    for track in info['media']['track']:
        if track['@type'] == 'Audio':
            if audio_info is not None:
                request_logger.error('Two audio tracks found in file', extra=general_log_extra)
                return None
            audio_info = track
    return audio_info


def get_meta(meta_file_path):
    if not os.path.isfile(meta_file_path):
        request_logger.info('No meta info available. Cannot find file: ' + meta_file_path, extra=general_log_extra)
        return {}

    with open(meta_file_path, 'r') as f:
        return json.load(f)


def is_format_supported(audio_info):
    supported_formats = [
        {
            'Format': 'PCM',
            'Format_Settings_Endianness': 'Little',
            'Format_Settings_Sign': 'Signed',
            'BitDepth': '16',
            'Channels': '1',
            'SamplingRate': ['8000', '16000', '32000'],
        },
        {
            'Format': 'Opus',
            'Channels': '1',
        },
    ]
    for supported_format in supported_formats:
        supported = True
        for key in supported_format:
            if isinstance(supported_format[key], str):
                if audio_info[key] != supported_format[key]:
                    supported = False
                    break
            elif isinstance(supported_format[key], collections.abc.Iterable):
                if not audio_info[key] in supported_format[key]:
                    supported = False
                    break
        if supported:
            return True
    return False


def get_specification(file_path, model, default_rate):
    meta_file_path = file_path[:-3] + 'json'
    if file_path.endswith('.ogg') or file_path.endswith('.opus'):
        audio_info = get_audio_info_from_mediainfo(file_path)
        if not is_format_supported(audio_info):
            return None, None, None
        return stt_service_pb2.RecognitionSpec(
            language_code='ru-RU',
            profanity_filter=False,
            model=model,
            partial_results=True,
            audio_encoding='OGG_OPUS',
        ), get_opus_bytes_per_sec(file_path), get_meta(meta_file_path)
    if file_path.endswith('.wav'):
        audio_info = get_audio_info_from_mediainfo(file_path)
        if not is_format_supported(audio_info):
            return None, None, None
        return stt_service_pb2.RecognitionSpec(
            language_code='ru-RU',
            profanity_filter=False,
            model=model,
            partial_results=True,
            audio_encoding='LINEAR16_PCM',
            sample_rate_hertz=int(audio_info['SamplingRate']),
        ), get_opus_bytes_per_sec(file_path), get_meta(meta_file_path)
    elif file_path.endswith('.pcm') or file_path.endswith('.raw'):
        audio_format, audio_channels, audio_rate = extract_format_from_name(file_path)
        if audio_format is None:
            return stt_service_pb2.RecognitionSpec(
                language_code='ru-RU',
                profanity_filter=False,
                model=model,
                partial_results=True,
                audio_encoding='LINEAR16_PCM',
                sample_rate_hertz=default_rate,
            ), default_rate * 2, get_meta(meta_file_path)
        audio_channels, audio_rate = int(audio_channels), int(audio_rate)
        if audio_format == supported_format and audio_channels == supported_channels:
            meta_file_path = '.'.join(file_path.split('.')[:-2] + ['json'])
            return stt_service_pb2.RecognitionSpec(
                language_code='ru-RU',
                profanity_filter=False,
                model=model,
                partial_results=True,
                audio_encoding='LINEAR16_PCM',
                sample_rate_hertz=audio_rate,
            ), audio_rate * 2, get_meta(meta_file_path)
    return None, 0, {}


def init_whiteboard(gen_descriptor, req_id):
    whiteboard = {
        'events': collections.deque(copy.deepcopy(gen_descriptor.meta.get('events', []))),
        'events_sent': collections.deque(),
        'events_responded': collections.deque(),
        'request_id': req_id
    }
    return whiteboard


def print_whiteboard(whiteboard, log_extra):
    whiteboard['events'] = list(whiteboard['events'])
    whiteboard['events_sent'] = list(whiteboard['events_sent'])
    whiteboard['events_responded'] = list(whiteboard['events_responded'])
    request_logger.info('Whiteboard: ' + json.dumps(whiteboard, ensure_ascii=False, sort_keys=True), extra=log_extra)


class ErrorDetails:
    def __init__(self, ts, req_id):
        self.timestamp = ts
        self.request_id = req_id

    def to_str(self):
        return "ts: %s req_id: %s" % (self.timestamp, self.request_id)


def init_stats():
    return {
        'requests': 0,
        'errors': 0,
        'errors_details': collections.defaultdict(list),

        'events_latency': collections.defaultdict(list)
    }


def update_stats(stats, whiteboard):
    stats['requests'] += 1
    if whiteboard['rpc_result'] != 0:
        stats['errors'] += 1
        stats['errors_details'][str(whiteboard['rpc_result'])].append(
            ErrorDetails(whiteboard['stop'], whiteboard['request_id']))

    for event in whiteboard['events_responded']:
        stats['events_latency'][(event['type'], event['time'])].append(event['latency'])
    if 'last_response_time' in whiteboard:
        stats['events_latency']['last_response_time'].append(whiteboard['last_response_time'])


def calc_stats(event, source, target):
    for q in percentiles_to_calc:
        target[str(event)]['p' + str(q)] = numpy.percentile(source[event], q)
    target[str(event)]['avg'] = numpy.average(source[event])


def print_stats(stats, tag=''):
    processed_stats = copy.deepcopy(stats)
    processed_stats['errors_percent'] = stats['errors'] / stats['requests']
    processed_stats['errors_details_percent'] = {}
    for err in stats['errors_details']:
        processed_stats['errors_details_percent'][err] = float(len(stats['errors_details'][err])) / stats['requests']

    processed_stats['events_latency'] = collections.defaultdict(dict)
    accumulated_events_stats = collections.defaultdict(list)
    for event in stats['events_latency']:
        if isinstance(event, tuple) and len(event) > 1:
            accumulated_events_stats[event[0]] += stats['events_latency'][event]
        calc_stats(event, stats['events_latency'], processed_stats['events_latency'])

    for event in accumulated_events_stats:
        calc_stats(event, accumulated_events_stats, processed_stats['events_latency'])

    request_logger.info(
        tag + ' stats: ' + json.dumps(processed_stats, indent=2, separators=(',', ': '), sort_keys=True),
        extra=general_log_extra)


def gen_data(gen_descriptor, whiteboard, log_extra):
    start = whiteboard['start']
    request_logger.debug('Start streaming', extra=log_extra)
    yield stt_service_pb2.StreamingRecognitionRequest(config=gen_descriptor.streaming_config)
    try:
        reader = io.BytesIO(gen_descriptor.data)
        sleep_time = float(gen_descriptor.chunk_size) / gen_descriptor.bytes_per_sec - gen_descriptor.adjust_time
        total_sent = 0
        while True:
            data_chunk = reader.read(gen_descriptor.chunk_size)
            if not data_chunk:
                break

            time.sleep(sleep_time)
            total_sent += len(data_chunk)
            total_time_sent = float(total_sent) / gen_descriptor.bytes_per_sec
            curr_time = time.time() - start
            while whiteboard['events'] and whiteboard['events'][0]['time'] < total_time_sent:
                whiteboard['events'][0]['time_sent'] = curr_time
                request_logger.debug('Event sent: ' + json.dumps(whiteboard['events'][0], ensure_ascii=False),
                                     extra=log_extra)
                whiteboard['events_sent'].append(whiteboard['events'][0])
                whiteboard['events'].popleft()
            request_logger.debug(str(curr_time) + ' Chunk sent, size: %d, total_sent: %d, total_time_sent: %f' % (
                gen_descriptor.chunk_size, total_sent, total_time_sent), extra=log_extra)
            yield stt_service_pb2.StreamingRecognitionRequest(audio_content=data_chunk)
        whiteboard['eos'] = time.time()
    except Exception as e:
        request_logger.warning('Something went wrong: ' + str(e), extra=log_extra)
    request_logger.debug('Stop streaming', extra=log_extra)


def check_event_responded(event, resp, log_extra):
    if event['type'] == 'eou':
        return resp.chunks[0].end_of_utterance
    elif event['type'] == 'word':
        for alternative in resp.chunks[0].alternatives:
            for w in event['reference']:
                if w in alternative.text.lower():
                    return True
        return False
    else:
        request_logger.warning('Unsupported event type: ' + event['type'], extra=log_extra)

    return False


def check_events_responded(whiteboard, resp, log_extra):
    i = 0
    n = len(whiteboard['events_sent'])
    curr_time = time.time() - whiteboard['start']
    while i < n:
        event = whiteboard['events_sent'][i]
        if check_event_responded(event, resp, log_extra):
            event['time_responded'] = curr_time
            event['latency'] = curr_time - event['time_sent']
            request_logger.debug('Event responded: ' + json.dumps(event, ensure_ascii=False), extra=log_extra)
            whiteboard['events_responded'].append(whiteboard['events_sent'][i])
            del whiteboard['events_sent'][i]
            n = n - 1
        else:
            i = i + 1


def get_date():
    return str(datetime.date.today())


def run(endpoint_descriptor, gen_descriptor, handlerStats):
    while True:
        req_id = str(uuid.uuid4())
        log_extra = {'id': req_id}
        if endpoint_descriptor.ssl:
            cred = grpc.ssl_channel_credentials()
            channel = grpc.secure_channel(endpoint_descriptor.host, cred)
        else:
            channel = grpc.insecure_channel(endpoint_descriptor.host)
        stub = stt_service_pb2_grpc.SttServiceStub(channel)

        request_logger.info('RPC start', extra=log_extra)

        whiteboard = init_whiteboard(gen_descriptor, req_id)
        start = time.time()
        whiteboard['start'] = start
        it = stub.StreamingRecognize(gen_data(gen_descriptor, whiteboard, log_extra), metadata=(
            ('authorization', 'Api-Key ' + api_key),
            ('x-client-request-id', req_id),
            ('x-normalize-partials', 'true'),
            ('x-sensitivity-reduction-flag', 'true'),
            # ('x-data-logging-enabled', 'true'),
        ))

        try:
            for resp in it:
                request_logger.debug(str(time.time() - start) + ' Message received:', extra=log_extra)
                request_logger.debug(text_format.MessageToString(resp, as_utf8=True), extra=log_extra)
                check_events_responded(whiteboard, resp, log_extra)

            whiteboard['rpc_result'] = 0
            request_logger.info('RPC finished: Сode OK', extra=log_extra)
        except grpc._channel._Rendezvous as err:
            whiteboard['rpc_result'] = (err._state.code.name, err._state.details)
            request_logger.warning('RPC finished: Error сode %s, message: %s' % (err._state.code, err._state.details),
                                   extra=log_extra)

        whiteboard['stop'] = time.time()
        if 'eos' in whiteboard:
            whiteboard['last_response_time'] = whiteboard['stop'] - whiteboard['eos']
        print_whiteboard(whiteboard, log_extra)
        update_stats(handlerStats.stats, whiteboard)
        handlerStats.on_stats_updated(whiteboard)


def get_gen_descriptor(file_path, model, default_rate, chunk_duration_ms, adjust_time):
    if not os.path.isfile(file_path):
        request_logger.critical('Cannot find file: ' + file_path, extra=general_log_extra)
        return None

    specification, bytes_per_sec, meta = get_specification(file_path, model, default_rate)
    if specification is None:
        request_logger.critical('Format is not supported', extra=general_log_extra)
        return None

    streaming_config = stt_service_pb2.RecognitionConfig(specification=specification)

    with open(file_path, 'rb') as f:
        data = f.read()
    chunk_size = int(bytes_per_sec * chunk_duration_ms / 1000)
    return GenDescriptor(data=data, streaming_config=streaming_config, chunk_size=chunk_size,
                         bytes_per_sec=bytes_per_sec, adjust_time=adjust_time, meta=meta)


def create_logger(logger_name, logger_format, log_path, verbose):
    new_logger = logging.getLogger(logger_name)
    file_handler = logging.FileHandler(log_path)
    file_handler.setLevel(logging.DEBUG)

    request_formatter = logging.Formatter(logger_format)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.DEBUG if verbose else logging.INFO)

    file_handler.setFormatter(request_formatter)
    console_handler.setFormatter(request_formatter)

    new_logger.addHandler(console_handler)
    new_logger.addHandler(file_handler)
    new_logger.setLevel(logging.DEBUG)


def init_logger(verbose, log_path):
    logger_format = '%(asctime)-15s %(id)s %(levelname)-9s %(message)s'
    create_logger('request_logger', logger_format, log_path, verbose)
    request_logger.propagate = False

    create_logger(None, '%(asctime)-15s %(levelname)-9s %(message)s', log_path, verbose)


class StatsHandler:
    def __init__(self):
        self.stats = init_stats()
        self.last_stat_reset = get_date()
        self.last_stat_print = 0

    def on_stats_updated(self, whiteboard):
        if whiteboard['stop'] - self.last_stat_print > 60.0:
            self.last_stat_print = whiteboard['stop']
            print_stats(self.stats)
        if get_date() != self.last_stat_reset:
            self.last_stat_reset = get_date()
            print_stats(self.stats, tag='daily')
            self.stats = init_stats()


def get_descriptors():
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--data-path', help='path to test file',
                        default=os.path.join(script_dir_path, 'continious_test.s16le-ac1-ar8000.raw'))
    parser.add_argument('-m', '--model', help='model of recognition', default='general')
    parser.add_argument('--host', help='endpoint to run recognition', default='stt.api.cloud.yandex.net:443')
    parser.add_argument('-d', '--disable-ssl', help='use insecure channel', default=False, action='store_true')
    parser.add_argument('-c', '--chunk-duration', help='chunk duration in milliseconds', default=125, type=int)
    parser.add_argument('-r', '--sample-rate', help='default value for sample rate', default=8000, type=int)
    parser.add_argument('-a', '--adjust-time', help='serving time cost', default=0.0047, type=float)
    parser.add_argument('-v', '--verbose', help='verbose logs', default=False, action='store_true')
    parser.add_argument('-l', '--log-path', help='log path', default=os.path.join(script_dir_path, 'stt_runner.log'))
    args = parser.parse_args()

    init_logger(args.verbose, args.log_path)
    request_logger.info('More information in stt_runner.log', extra=general_log_extra)
    gen_descriptor = get_gen_descriptor(args.data_path, args.model, args.sample_rate, args.chunk_duration,
                                        args.adjust_time)
    if not gen_descriptor:
        request_logger.critical('Unable to get generator spec', extra=general_log_extra)
        sys.exit(1)

    return EndpointDescriptor(host=args.host, ssl=(not args.disable_ssl)), gen_descriptor, args


def main():
    endpoint_descriptor, gen_descriptor, _ = get_descriptors()
    run(endpoint_descriptor, gen_descriptor, StatsHandler())


if __name__ == '__main__':
    main()
