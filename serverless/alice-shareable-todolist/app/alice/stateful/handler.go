package stateful

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	aliceauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/cache"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	"go.uber.org/zap"
)

type Handler struct {
	todoListService  todolist.Service
	authService      aliceauth.Service
	logger           *zap.Logger
	stateScenarios   map[aliceapi.State]scenario
	scratchScenarios []scenario
}

func NewHandler(deps Deps) (*Handler, error) {
	h := &Handler{
		todoListService: deps.GetTODOListService(),
		authService:     deps.GetAliceAuthService(),
		logger:          deps.GetLogger(),
	}
	h.setupScenarios()
	return h, nil
}

func (h *Handler) Handle(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, error) {
	sessionID := req.Session.SessionID
	ctx = log.CtxWithLogger(ctx, h.logger.With(zap.String("sessionID", string(sessionID))))
	ctx = cache.ContextWithCache(ctx)
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
	resp.Version = req.Version
	return resp, nil
}

func (h *Handler) handle(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Session.New || req.AccountLinkingComplete != nil {
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: "Давайте я помогу вам со списками!",
		}}, nil
	}
	if state := req.State.Session; state.State != aliceapi.StateInit {
		intents := req.Request.NLU.Intents
		if req.Request.Type == aliceapi.RequestTypeSimple && intents.Cancel != nil || intents.Reject != nil {
			return &aliceapi.Response{
				Response: &aliceapi.Resp{Text: "Чем я могу помочь?"},
			}, nil
		}
		scenario, ok := h.stateScenarios[state.State]
		if ok {
			resp, err := scenario(ctx, req)
			if err != nil {
				return nil, err
			}
			if resp != nil {
				return resp, nil
			}
		}
	}
	for _, s := range h.scratchScenarios {
		resp, err := s(ctx, req)
		if err != nil {
			return nil, err
		}
		if resp != nil {
			return resp, err
		}
	}
	return &aliceapi.Response{Response: &aliceapi.Resp{
		Text: "Я вас не поняла",
	}}, nil
}

func (h *Handler) reportError(ctx context.Context, err errors.Err) (*aliceapi.Response, error) {
	errors.Log(ctx, err)
	return nil, err
}
