package web

import (
	"net/http"
	"net/url"

	"github.com/go-openapi/runtime"
	"github.com/go-openapi/runtime/middleware"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/restapi/operations"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	webauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web/auth"
)

type apiImpl struct {
	listsService todolist.Service
	authService  webauth.Service
}

func newAPI(deps Deps) (*apiImpl, error) {
	return &apiImpl{
		listsService: deps.GetTODOListService(),
		authService:  deps.GetWebAuthService(),
	}, nil
}

func (a *apiImpl) ListLists(req operations.ListListsParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	var errResp operations.ListListsDefault
	res, err := a.listsService.GetUserLists(ctx, &todolist.GetUserListsRequest{})
	if err != nil {
		return a.handleError(ctx, err, &errResp)
	}
	return &operations.ListListsOK{
		Payload: listShortToWebList(res),
	}
}

func (a *apiImpl) CreateList(req operations.CreateListParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	if req.Body.Name == nil {
		return a.handleError(ctx,
			errors.NewBadRequest("name is required"), &operations.CreateListDefault{})
	}
	id, err := a.listsService.Create(ctx, &todolist.ListCreateRequest{Name: *req.Body.Name})
	if err != nil {
		return a.handleError(ctx, err, &operations.CreateListDefault{})
	}
	idStr := string(id)
	return &operations.CreateListOK{Payload: &operations.CreateListOKBody{ID: &idStr}}
}

func (a *apiImpl) GetList(req operations.GetListParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	var errResp operations.ListListsDefault
	list, acl, err := a.listsService.Get(ctx, &todolist.ListGetRequest{ID: model.TODOListID(req.ListID)})
	if err != nil {
		return a.handleError(ctx, err, &errResp)
	}
	return &operations.GetListOK{
		Payload: listToWeb(acl, list),
	}
}

func (a *apiImpl) UserInfo(req operations.UserInfoParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return a.handleError(ctx, err, &operations.UserInfoDefault{})
	}
	return &operations.UserInfoOK{Payload: userInfoToWeb(user)}
}

func (a *apiImpl) ListUsers(req operations.GetListUsersParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	acl, err := a.listsService.GetListUsers(ctx, &todolist.GetListACLRequest{ID: model.TODOListID(req.ListID)})
	if err != nil {
		return a.handleError(ctx, err, &operations.GetListUsersDefault{})
	}
	user := auth.UserFromCtxOrPanic(ctx)
	return &operations.GetListUsersOK{Payload: listUsersToWeb(acl, user.ID)}
}

func (a *apiImpl) InviteUser(req operations.InviteUserParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	if req.Body.AccessMode == nil || req.Body.Invitee == nil {
		return a.handleError(ctx,
			errors.NewBadRequest("invitee and access_mode are required"), &operations.InviteUserDefault{})
	}
	invitee := *req.Body.Invitee
	accessMode, err := accessModeFromWeb(*req.Body.AccessMode)
	if err != nil {
		return a.handleError(ctx, err, &operations.InviteUserDefault{})
	}
	err = a.listsService.InviteUser(ctx, &todolist.InviteRequest{
		ListID:  model.TODOListID(req.ListID),
		Invitee: model.UserID(invitee),
		Access:  accessMode,
	})
	if err != nil {
		return a.handleError(ctx, err, &operations.InviteUserDefault{})
	}
	return &operations.InviteUserNoContent{}
}

func (a *apiImpl) AcceptInvitation(req operations.AcceptInvitationParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	if req.Body.Alias == nil {
		return a.handleError(ctx,
			errors.NewBadRequest("alias is required"), &operations.InviteUserDefault{})
	}
	err := a.listsService.AcceptAndRenameList(ctx, &todolist.AcceptAndRenameListRequest{
		ListID: model.TODOListID(req.ListID),
		Alias:  *req.Body.Alias,
	})
	if err != nil {
		return a.handleError(ctx, err, &operations.AcceptInvitationDefault{})
	}
	return &operations.AcceptInvitationNoContent{}
}

func (a *apiImpl) DeleteList(req operations.DeleteListParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	err := a.listsService.RemoveList(ctx, &todolist.RemoveListRequest{ID: model.TODOListID(req.ListID)})
	if err != nil {
		return a.handleError(ctx, err, &operations.DeleteListDefault{})
	}
	return &operations.DeleteListNoContent{}
}

func (a *apiImpl) RevokeInvitation(req operations.RevokeInvitationParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	err := a.listsService.RevokeInvitation(ctx, &todolist.InvitationRevokeRequest{
		ListID:  model.TODOListID(req.ListID),
		Invitee: model.UserID(req.UserID),
	})
	if err != nil {
		return a.handleError(ctx, err, &operations.RevokeInvitationDefault{})
	}
	return &operations.RevokeInvitationNoContent{}
}

func (a *apiImpl) AddListItem(req operations.AddItemParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	if req.Body.Text == nil {
		return a.handleError(ctx,
			errors.NewBadRequest("text is required"), &operations.AddItemDefault{})
	}
	err := a.listsService.AddItem(ctx, &todolist.ItemAddRequest{
		ListID: model.TODOListID(req.ListID),
		Text:   *req.Body.Text,
		Mode:   todolist.ItemAppend,
	})
	if err != nil {
		return a.handleError(ctx, err, &operations.AddItemDefault{})
	}
	return &operations.AcceptInvitationNoContent{}
}

func (a *apiImpl) DeleteListItem(req operations.DeleteItemParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	err := a.listsService.RemoveItem(ctx, &todolist.ItemRemoveRequest{
		ListID: model.TODOListID(req.ListID),
		ItemID: model.ListItemID(req.ItemID),
	})
	if err != nil {
		return a.handleError(ctx, err, &operations.DeleteItemDefault{})
	}
	return &operations.DeleteItemNoContent{}
}

func (a *apiImpl) LoginPage(req operations.PageLoginParams) middleware.Responder {
	ctx := req.HTTPRequest.Context()
	oauthPageURL := a.authService.GetOAuthURL(ctx, nil, true)
	return &operations.PageLoginFound{
		Location: oauthPageURL.String(),
	}
}

func (a *apiImpl) YandexOAuthPage(req operations.PageReceiveTokenParams) middleware.Responder {
	return directResponder(func(rw http.ResponseWriter) {
		_, err := a.authService.CreateSessionForOAuthUser(req.HTTPRequest, rw, req.Code)
		if err != nil {
			//TODO
			errors.Log(req.HTTPRequest.Context(), err)
			rw.WriteHeader(500)
			rw.Write([]byte("<html><body><h1>ERROR</h1></body</html>"))
			return
		}
		redirUrl := &url.URL{Path: "/"}
		if req.State != nil {
			state := *req.State
			stateUrl, urlErr := url.Parse(state)
			if urlErr == nil {
				redirUrl = stateUrl
			}
		}
		redirUrl.Host = ""
		redirUrl.Scheme = ""
		redirUrl.User = nil

		rw.WriteHeader(302)
		rw.Header().Add("Location", redirUrl.String())
	})
}

type directResponder func(rw http.ResponseWriter)

func (r directResponder) WriteResponse(rw http.ResponseWriter, p runtime.Producer) {
	r(rw)
}
