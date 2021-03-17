package auth

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
)

type Service interface {
	AuthenticateAlice(ctx context.Context, req *aliceapi.Request) (context.Context, errors.Err)
}

func NewService(deps Deps) (Service, error) {
	return &service{
		authService: deps.GetAuthService(),
		repo:        deps.GetRepository(),
	}, nil
}

var _ Service = &service{}

type service struct {
	authService auth.Service
	repo        db.Repository
}

func (s *service) AuthenticateAlice(ctx context.Context, req *aliceapi.Request) (context.Context, errors.Err) {
	if req.Session.User.Token == "" {
		return ctx, errors.NewUnauthenticated()
	}
	user, err := s.authService.GetOrCreateOAuthUserForToken(ctx, req.Session.User.Token)
	if err != nil {
		return ctx, err
	}
	return auth.CtxWithUser(ctx, user), nil
}
