import json
import os
import base64
import datetime
import hashlib
import hmac
import requests
import argparse
import re


# http://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html#signature-v4-examples-python
def sign(key, msg):
    x = hmac.new(key, msg.encode(), hashlib.sha256)
    return x


def get_signature_key(key, date_stamp, region_name, service_name):
    secret = f'AWS4{key}'.encode()
    date = sign(secret, date_stamp)
    region = sign(date.digest(), region_name)
    service = sign(region.digest(), service_name)
    signing = sign(service.digest(), 'aws4_request')
    return signing


def send_message2(access_key, secret_key, region, folder_id, database_id, stream_name, message):
    stream_full_name = f'/{region}/{folder_id}/{database_id}/{stream_name}'
    return send_message(access_key, secret_key, stream_full_name, message)


def send_message(access_key, secret_key, stream_full_name, message):
    method = 'POST'
    service = 'kinesis'
    content_type = 'application/x-amz-json-1.1'
    amz_target = 'Kinesis_20131202.PutRecord'
    region = stream_full_name.split("/")[1]

    encoded_message = message.encode()
    data = base64.b64encode(bytearray(encoded_message)).decode()

    hash_object = hashlib.md5(encoded_message)

    request_parameters = {"StreamName": stream_full_name,
                          "Data": data,
                          "PartitionKey": hash_object.hexdigest()}
    request_parameters_bin = json.dumps(request_parameters).encode()

    # Create a date for headers and the credential string
    t = datetime.datetime.utcnow()
    amz_date = t.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = t.strftime('%Y%m%d')  # Date w/o time, used in credential scope

    host = 'yds.serverless.yandexcloud.net'
    canonical_uri = '/'
    canonical_querystring = ''
    canonical_headers = 'content-type:' + content_type + '\n' + \
                        'host:' + host + '\n' + \
                        'x-amz-date:' + amz_date + '\n' + \
                        'x-amz-target:' + amz_target + '\n'

    signed_headers = 'content-type;host;x-amz-date;x-amz-target'
    payload_hash = hashlib.sha256(request_parameters_bin).hexdigest()

    canonical_request = method + '\n' + \
                        canonical_uri + '\n' + \
                        canonical_querystring + '\n' + \
                        canonical_headers + '\n' + \
                        signed_headers + '\n' + \
                        payload_hash

    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = date_stamp + '/' + region + '/' + service + '/' + 'aws4_request'
    canonical_request_hash = hashlib.sha256(canonical_request.encode()).hexdigest()
    string_to_sign = algorithm + '\n' +  \
                     amz_date + '\n' + \
                     credential_scope + '\n' + \
                     canonical_request_hash

    signing_key = get_signature_key(secret_key, date_stamp, region, service)
    signature = hmac.new(signing_key.digest(), string_to_sign.encode(), hashlib.sha256).hexdigest()

    authorization_header = algorithm + ' ' + \
                           'Credential=' + access_key + \
                           '/' + credential_scope + ', ' + \
                           'SignedHeaders=' + signed_headers + ', ' + \
                           'Signature=' + signature

    headers = {
        'Content-Type': content_type,
        'X-Amz-Date': amz_date,
        'X-Amz-Target': amz_target,
        'Authorization': authorization_header}

    endpoint = 'https://' + host

    # ************* SEND THE REQUEST *************
    print('BEGIN REQUEST++++++++++++++++++++++++++++++++++++')
    print(f'Request URL = {endpoint}')
    print(f'Headers:\n{headers}')
    print(f'Request:\n{request_parameters}')
    r = requests.post(endpoint, json=request_parameters, headers=headers)
    print('\nRESPONSE++++++++++++++++++++++++++++++++++++')
    print(f'Response code: {r.status_code}')
    print(f'{r.text}')


def main():
    if  "AWS_ACCESS_KEY_ID" not in os.environ or "AWS_SECRET_ACCESS_KEY" not in os.environ:
        print("Please provide credentials in AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables")
        exit(-1)

    parser = argparse.ArgumentParser()
    parser.add_argument('--full-stream-name', type=str, required=True,
                        help='Full stream name')
    parser.add_argument('--message', type=str, required=True,
                        help='Message to send')

    args = parser.parse_args()

    stream_regex = re.compile('^/.+/\\w{15,}/\\w{20,}/\\w{3,}$', re.IGNORECASE)
    if not stream_regex.match(args.full_stream_name):
        print('Check your stream name. \n' \
              'It must be like /ru-central1/b2g6ad43m6he1ooql98r/etn01eh5rn074ncm9cbb/your_stream_name.\n'
              '/region/folder_id/database_id/your_stream_name'
              )
        exit(-1)

    # replace with your own stream name and provide environment keys
    send_message(access_key=os.environ["AWS_ACCESS_KEY_ID"],
                 secret_key=os.environ["AWS_SECRET_ACCESS_KEY"],
                 stream_full_name=args.full_stream_name,
                 message=args.message)


if __name__ == "__main__":
    main()
