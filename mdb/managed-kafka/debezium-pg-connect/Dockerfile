FROM confluentinc/cp-kafka-connect-base:latest

ARG HOME=/home/appuser

USER root

ADD https://storage.yandexcloud.net/cloud-certs/CA.pem ${HOME}/YandexCA.pem
RUN chown appuser:appuser ${HOME}/YandexCA.pem
ADD ./src ${HOME}/src
RUN chown -R appuser:appuser ${HOME}/src
RUN chmod 500 ~/src/cmd.sh
USER appuser

RUN keytool -keystore ${HOME}/client.truststore.jks -noprompt -alias CARoot -import -file ${HOME}/YandexCA.pem -storepass truststore
RUN mkdir ${HOME}/config
RUN cp ${HOME}/src/connector.properties ${HOME}/config
RUN mkdir ${HOME}/plugins

CMD /home/appuser/src/cmd.sh
