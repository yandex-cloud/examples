cat << EOF > ${HOME}/config/worker.properties
log4j.rootLogger=DEBUG, stderr
# AdminAPI connect properties
bootstrap.servers=${BROKERS}
sasl.mechanism=SCRAM-SHA-512
security.protocol=SASL_SSL
ssl.truststore.location=${HOME}/client.truststore.jks
ssl.truststore.password=truststore
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${USER}" password="${PASSWORD}";
# Producer connect properties
producer.sasl.mechanism=SCRAM-SHA-512
producer.security.protocol=SASL_SSL
producer.ssl.truststore.location=${HOME}/client.truststore.jks
producer.ssl.truststore.password=truststore
producer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${USER}" password="${PASSWORD}";
# Consumer connect properties
consumer.sasl.mechanism=SCRAM-SHA-512
consumer.security.protocol=SASL_SSL
consumer.ssl.truststore.location=${HOME}/client.truststore.jks
consumer.ssl.truststore.password=truststore
consumer.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${USER}" password="${PASSWORD}";
# Worker properties
plugin.path=${HOME}/plugins
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=true
value.converter.schemas.enable=true
offset.storage.file.filename=${HOME}/worker.offset
offset.flush.interval.ms=1000
EOF

connect-standalone ~/config/worker.properties ~/config/connector.properties
