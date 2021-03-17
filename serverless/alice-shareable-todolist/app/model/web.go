package model

type WebSessionID string
type WebSession struct {
	ID   WebSessionID
	User UserID
}
