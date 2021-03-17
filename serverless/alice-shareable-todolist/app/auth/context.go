package auth

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

type userKey struct{}

func UserFromCtxOrErr(ctx context.Context) (*model.User, errors.Err) {
	user := UserFromCtx(ctx)
	if user == nil {
		return nil, errors.NewUnauthenticated()
	}
	return user, nil
}

func UserFromCtxOrPanic(ctx context.Context) *model.User {
	res := UserFromCtx(ctx)
	if res == nil {
		panic("user not found in context")
	}
	return res
}

func UserFromCtx(ctx context.Context) *model.User {
	res := ctx.Value(userKey{})
	if res == nil {
		return nil
	}
	return res.(*model.User)
}

func CtxWithUser(ctx context.Context, user *model.User) context.Context {
	return context.WithValue(ctx, userKey{}, user)
}
