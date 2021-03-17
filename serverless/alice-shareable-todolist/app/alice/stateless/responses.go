package stateless

import (
	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

func selectList(text *aliceText, options []*model.ACLEntry) *aliceapi.Resp {
	var buttons []*aliceapi.Button
	for _, opt := range options {
		buttons = append(buttons, &aliceapi.Button{
			Title:   opt.Alias,
			Payload: &aliceapi.ButtonPayload{ChooseListID: opt.ListID},
			Hide:    true,
		})
	}
	return &aliceapi.Resp{
		Text:       text.text,
		TTS:        text.tts,
		Buttons:    buttons,
		EndSession: false,
	}
}

type aliceText struct {
	text string
	tts  string
}

func newText(text string) *aliceText {
	return &aliceText{text: text}
}

func newTextWithTTS(text, tts string) *aliceText {
	return &aliceText{
		text: text,
		tts:  tts,
	}
}
