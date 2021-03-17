package auth

import (
	"context"
	"fmt"
	"net/http"
	"net/url"

	"github.com/gorilla/sessions"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

const cookieSessionID = "session_id"
const sessionKeyUserID = "user_id"

type Service interface {
	GetOAuthURL(ctx context.Context, retPath *url.URL, force bool) *url.URL
	CreateSessionForOAuthUser(req *http.Request, rw http.ResponseWriter, oauthCode string) (*model.User, errors.Err)
	Middleware(h http.Handler) http.Handler
}

var _ Service = &service{}

type service struct {
	authService auth.Service
	repo        db.Repository
	domain      string
	sessions    *sessions.CookieStore
}

func NewService(deps Deps) (Service, error) {
	sessionStore, err := createSessions(deps)
	if err != nil {
		return nil, err
	}
	conf := deps.GetConfig()
	return &service{
		authService: deps.GetAuthService(),
		repo:        deps.GetRepository(),
		domain:      conf.Domain,
		sessions:    sessionStore,
	}, nil
}

func createSessions(deps Deps) (*sessions.CookieStore, error) {
	keysConf := deps.GetSecureConfig().SessionKeys
	if len(keysConf) == 0 {
		return nil, fmt.Errorf("SessionKeys missing from secure config")
	}
	keys := make([][]byte, 0, len(keysConf)*2)
	for _, key := range keysConf {
		keys = append(keys, key.HashKey, key.BlockKey)
	}
	return sessions.NewCookieStore(keys...), nil
}

func (s *service) getSession(req *http.Request) (*sessions.Session, errors.Err) {
	session, err := s.sessions.Get(req, "session")
	if err != nil {
		return nil, errors.NewInternal(err)
	}
	return session, nil
}

func (s *service) Middleware(h http.Handler) http.Handler {
	return &authMiddleware{
		service:  s,
		delegate: h,
	}
}

func (s *service) CreateSessionForOAuthUser(req *http.Request, rw http.ResponseWriter, oauthCode string) (*model.User, errors.Err) {
	user, err := s.authService.GetOrCreateOAuthUserForCode(req.Context(), oauthCode)
	if err != nil {
		return nil, err
	}
	session, err := s.getSession(req)
	if err != nil {
		return nil, err
	}
	session.Values[sessionKeyUserID] = string(user.ID)
	intErr := session.Save(req, rw)
	if intErr != nil {
		return nil, errors.NewInternal(intErr)
	}
	return user, nil
}

func (s *service) GetOAuthURL(ctx context.Context, retPath *url.URL, force bool) *url.URL {
	var redirURL url.URL
	redirURL.Path = "/receive-token"
	state := ""
	if retPath != nil {
		state = retPath.String()
	}
	return s.authService.GetOAuthURL(ctx, auth.OAuthForce(force), auth.OAuthRetPath(&redirURL), auth.OAuthState(state))
}
