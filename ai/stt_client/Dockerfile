FROM python:3

ADD google /google
ADD yandex /yandex
ADD continious_test.s16le-ac1-ar8000.raw continious_test.json stt_runner.py /

RUN pip install protobuf grpcio numpy

ENTRYPOINT ["python", "stt_runner.py"]

