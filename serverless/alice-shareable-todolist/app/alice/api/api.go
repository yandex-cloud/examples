package api

import (
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

type Request struct {
	Version                string    `json:"version"`
	Session                Session   `json:"session"`
	Request                *Req      `json:"request"`
	AccountLinkingComplete *EmptyObj `json:"account_linking_complete_event"`
	State                  ReqState  `json:"state"`
}

type ReqState struct {
	Session StateData `json:"session"`
}

type Session struct {
	MessageID int                  `json:"message_id"`
	SessionID model.AliceSessionID `json:"session_id"`
	User      *User                `json:"user"`
	New       bool                 `json:"new"`
}

type User struct {
	ID    string `json:"user_id"`
	Token string `json:"access_token"`
}

type RequestType string

const (
	RequestTypeSimple RequestType = "SimpleUtterance"
	RequestTypeButton RequestType = "ButtonPressed"
)

type Req struct {
	Command           string         `json:"command"`
	OriginalUtterance string         `json:"original_utterance"`
	NLU               NLU            `json:"nlu"`
	Type              RequestType    `json:"type"`
	Payload           *ButtonPayload `json:"payload"`
}

type NLU struct {
	Tokens  []string `json:"tokens"`
	Intents Intents  `json:"intents"`
}

type TokensRef struct {
	Start int `json:"start"`
	End   int `json:"end"`
}

type Resp struct {
	Text       string    `json:"text"`
	TTS        string    `json:"tts"`
	Buttons    []*Button `json:"buttons"`
	EndSession bool      `json:"end_session"`
}

type Button struct {
	Title   string         `json:"title"`
	Payload *ButtonPayload `json:"payload"`
	URL     string         `json:"url,omitempty"`
	Hide    bool           `json:"hide"`
}

type Response struct {
	Version             string     `json:"version"`
	Response            *Resp      `json:"response"`
	StartAccountLinking *EmptyObj  `json:"start_account_linking"`
	State               *StateData `json:"session_state"`
}

type ButtonPayload struct {
	ChooseListID   model.TODOListID `json:"choose_list_id,omitempty"`
	ChooseListName string           `json:"choose_list_name,omitempty"`
	CreateList     bool             `json:"create_list,omitempty"`
	ChooseItemText string           `json:"choose_item_text,omitempty"`
	ChooseItemID   model.ListItemID `json:"choose_item_id,omitempty"`
}

type EmptyObj struct {
}
