package auth

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

type sessionKey struct{}

func CtxWithSession(ctx context.Context, session *model.AliceSession) context.Context {
	return context.WithValue(ctx, sessionKey{}, session)
}

func SessionFromCtx(ctx context.Context) *model.AliceSession {
	value := ctx.Value(sessionKey{})
	if value == nil {
		return nil
	}
	return value.(*model.AliceSession)
}
