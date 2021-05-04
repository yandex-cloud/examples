package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
)

// Пример данных которые получаем от устройства.
type MessageFromDevice struct {
	Temperature  float32 `json:"temperature"`
	SerialNumber string  `json:"serial_number"`
}

// Основная информация о сообщении.
type MessageDetails struct {
	DeviceID   string `json:"device_id"`
	MqttTopic  string `json:"mqtt_topic"`
	Payload    string `json:"payload"`
	RegistryID string `json:"registry_id"`
}

// Служебная информация о сообщении.
type MessageMetadata struct {
	CreatedAT string `json:"created_at"`
	EventID   string `json:"event_id"`
	EventType string `json:"event_type"`
	FolderID  string `json:"folder_id"`
}

// Сообщение, которое приходит внутри события.
type Message struct {
	Details  MessageDetails  `json:"details"`
	Metadata MessageMetadata `json:"event_metadata"`
}

// Событие, в котором находятся все новые сообщения от iot core.
type Event struct {
	Messages []Message `json:"messages"`
}

// Главная функция обработчик.
func Handler(ctx context.Context, inputEvent []byte) error {
	var event Event
	// Преобразуем входящий массив байт события в структуру.
	err := json.Unmarshal(inputEvent, &event)
	if err != nil {
		return err
	}
	// Обрабатываем все полученные сообщения.
	for _, eventMessage := range event.Messages {
		// Декодируем сообщение из base64 в массив byte.
		decodePayload, err := base64.StdEncoding.DecodeString(eventMessage.Details.Payload)
		if err != nil {
			return err
		}
		// Сообщение от устройства
		var message MessageFromDevice
		// Декодируем сообщение из массива byte в структуру.
		err = json.Unmarshal(decodePayload, &message)
		if err != nil {
			// Если сообщение не удалось декодировать, то отображаем ошибку, но не прерываем выполнение.
			fmt.Printf(
				"Ошибка декодирования. Топик: %s, Время получения: %s, ID устройства: %s, Ошибка: %s\n",
				eventMessage.Details.MqttTopic, eventMessage.Metadata.CreatedAT, eventMessage.Details.DeviceID,
				err.Error(),
			)
		} else {
			// Если сообщение успешно декодировано, то отображаем его.
			fmt.Printf(
				"Новое сообщение. Топик: %s, Время получения: %s, ID устройства: %s, Серийный номер: %s, Температура: %f\n",
				eventMessage.Details.MqttTopic, eventMessage.Metadata.CreatedAT, eventMessage.Details.DeviceID,
				message.SerialNumber, message.Temperature,
			)
		}
	}
	return nil
}
