// Copyright (c) 2019 Yandex LLC. All rights reserved.

package main

import (
	"crypto/tls"

	MQTT "github.com/eclipse/paho.mqtt.golang"
)

// See https://www.eclipse.org/paho/files/mqttdoc/MQTTClient/html/qos.html
type QoS byte

const (
	QosAtMostOnce  QoS = 0
	QosAtLeastOnce QoS = 1
)

type ClientSession struct {
	clientID string
	client   MQTT.Client
	messages chan string
}

func NewClentSession(address string, tlsConfig *tls.Config, clientID string) (session *ClientSession, err error) {
	session = &ClientSession{
		clientID: clientID,
		messages: make(chan string),
	}

	opts := MQTT.NewClientOptions().AddBroker(address)
	opts.SetClientID(clientID).SetTLSConfig(tlsConfig)
	opts.SetDefaultPublishHandler(session.OnMessage)
	session.client = MQTT.NewClient(opts)

	if token := session.client.Connect(); token.Wait() && token.Error() != nil {
		return nil, err
	}

	return session, nil
}

func (session *ClientSession) Disconnect() {
	session.client.Disconnect(250)
	close(session.messages)
}

func (session *ClientSession) OnMessage(client MQTT.Client, msg MQTT.Message) {
	session.messages <- string(msg.Payload())
}

func (session *ClientSession) Publish(topic string, payload string) error {
	token := session.client.Publish(topic, byte(QosAtLeastOnce), false, payload)
	token.Wait()
	return token.Error()
}

func (session *ClientSession) Subscribe(topic string) error {
	token := session.client.Subscribe(topic, byte(QosAtLeastOnce), nil)
	token.Wait()
	return token.Error()
}

func (session *ClientSession) GetMessages() chan string {
	return session.messages
}
