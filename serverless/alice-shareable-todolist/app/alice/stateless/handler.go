package stateless

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	aliceauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	"go.uber.org/zap"
)

type Handler struct {
	todoListService todolist.Service
	authService     aliceauth.Service
	logger          *zap.Logger
}

func NewHandler(deps Deps) (*Handler, error) {
	h := &Handler{
		todoListService: deps.GetTODOListService(),
		authService:     deps.GetAliceAuthService(),
		logger:          deps.GetLogger(),
	}
	return h, nil
}

func (h *Handler) Handle(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, error) {
	sessionID := req.Session.SessionID
	ctx = log.CtxWithLogger(ctx, h.logger.With(zap.String("sessionID", string(sessionID))))
	ctx, err := h.authService.AuthenticateAlice(ctx, req)
	if err != nil {
		if err.GetCode() == errors.CodeUnauthenticated {
			return &aliceapi.Response{
				Version:             req.Version,
				StartAccountLinking: &aliceapi.EmptyObj{},
			}, nil
		}
		return h.reportError(ctx, err)
	}
	resp, err := h.handle(ctx, req)
	if err != nil {
		return h.reportError(ctx, err)
	}
	return &aliceapi.Response{
		Version:  req.Version,
		Response: resp,
	}, nil
}

func (h *Handler) handle(ctx context.Context, req *aliceapi.Request) (*aliceapi.Resp, errors.Err) {
	if req.Session.New || req.AccountLinkingComplete != nil {
		return &aliceapi.Resp{
			Text: "Давайте я помогу вам со списками!",
		}, nil
	}
	scenarios := []func(context.Context, *aliceapi.Req) (*aliceapi.Resp, errors.Err){
		h.viewListScenario,
		h.listListsScenario,
		h.addItemScenario,
		h.deleteItemScenario,
		h.createListScenario,
	}
	for _, s := range scenarios {
		resp, err := s(ctx, req.Request)
		if err != nil {
			return nil, err
		}
		if resp != nil {
			return resp, err
		}
	}
	return &aliceapi.Resp{
		Text: "Я вас не поняла",
	}, nil
}

func (h *Handler) reportError(ctx context.Context, err errors.Err) (*aliceapi.Response, error) {
	errors.Log(ctx, err)
	return nil, err
}
