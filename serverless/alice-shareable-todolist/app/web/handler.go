package web

import (
	"context"
	"net/http"

	"github.com/go-openapi/loads"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/restapi"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/restapi/operations"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/util"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web/apigw"
	"go.uber.org/zap"
)

const apiPrefix = "/api"

var internalError = &apigw.Response{
	StatusCode: 500,
	Body:       `{"error": {"code": "INTERNAL", "message": "Internal server error"}}`,
}

type Handler struct {
	server http.Handler
	logger *zap.Logger
}

func NewHandler(deps Deps) (*Handler, error) {
	swaggerSpec, err := loads.Embedded(restapi.SwaggerJSON, restapi.FlatSwaggerJSON)
	if err != nil {
		return nil, err
	}

	api := operations.NewTodoListAPI(swaggerSpec)
	impl, err := newAPI(deps)
	if err != nil {
		return nil, err
	}

	setupMethods(api, impl)
	server := restapi.NewServer(api)
	server.ConfigureAPI()
	handler := server.GetHandler()
	handler = deps.GetWebAuthService().Middleware(handler)
	return &Handler{
		server: handler,
		logger: deps.GetLogger(),
	}, nil
}

func setupMethods(api *operations.TodoListAPI, impl *apiImpl) {
	api.CreateListHandler = operations.CreateListHandlerFunc(impl.CreateList)
	api.GetListHandler = operations.GetListHandlerFunc(impl.GetList)
	api.AddItemHandler = operations.AddItemHandlerFunc(impl.AddListItem)
	api.DeleteItemHandler = operations.DeleteItemHandlerFunc(impl.DeleteListItem)
	api.ListListsHandler = operations.ListListsHandlerFunc(impl.ListLists)
	api.GetListUsersHandler = operations.GetListUsersHandlerFunc(impl.ListUsers)
	api.InviteUserHandler = operations.InviteUserHandlerFunc(impl.InviteUser)
	api.AcceptInvitationHandler = operations.AcceptInvitationHandlerFunc(impl.AcceptInvitation)
	api.DeleteListHandler = operations.DeleteListHandlerFunc(impl.DeleteList)
	api.RevokeInvitationHandler = operations.RevokeInvitationHandlerFunc(impl.RevokeInvitation)

	api.PageLoginHandler = operations.PageLoginHandlerFunc(impl.LoginPage)
	api.PageReceiveTokenHandler = operations.PageReceiveTokenHandlerFunc(impl.YandexOAuthPage)
	api.UserInfoHandler = operations.UserInfoHandlerFunc(impl.UserInfo)
}

func (h *Handler) Handle(ctx context.Context, req *apigw.Request) *apigw.Response {
	requestID := req.HeaderString("X-Request-Id")
	if requestID == "" {
		requestID = util.GenerateID()
	}
	logger := h.logger.With(zap.String("requestID", requestID))
	ctx = log.CtxWithLogger(ctx, logger)
	httpReq, err := req.MakeHTTPRequest()
	if err != nil {
		logger.Error("failed to parse apigw request", zap.Error(err))
		return internalError
	}
	httpResp := apigw.NewResponseWriter()
	h.server.ServeHTTP(httpResp, httpReq.WithContext(ctx))
	return httpResp.ToResponse()
}
