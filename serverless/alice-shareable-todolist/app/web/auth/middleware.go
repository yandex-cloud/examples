package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

const oauthHeaderPrefix = "OAuth "

type authMiddleware struct {
	service  *service
	delegate http.Handler
}

func (m *authMiddleware) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	user := m.authenticate(req)
	if user != nil {
		req = req.WithContext(auth.CtxWithUser(req.Context(), user))
	}
	// either way proceed to handler since request going to be authorized at next layer
	// unauthenticated requests can be valid for actions that don't require authorization
	m.delegate.ServeHTTP(rw, req)
}

func (m *authMiddleware) authenticate(req *http.Request) *model.User {
	authHandlers := []func(*http.Request) (*model.User, errors.Err){
		m.authenticateCookie, m.authenticateOAuth,
	}
	for _, handler := range authHandlers {
		user, err := handler(req)
		if err != nil {
			m.handleAuthErr(req.Context(), err)
			continue
		}
		if user != nil {
			return user
		}
	}
	return nil
}

func (m *authMiddleware) handleAuthErr(ctx context.Context, err errors.Err) {
	errors.Log(ctx, err)
}

func (m *authMiddleware) authenticateCookie(req *http.Request) (*model.User, errors.Err) {
	s, err := m.service.getSession(req)
	if err != nil {
		return nil, err
	}
	userIdVal, ok := s.Values[sessionKeyUserID]
	var userIdStr string
	if ok {
		userIdStr, ok = userIdVal.(string)
	}
	if ok {
		return m.service.authService.GetPreAuthenticatedUser(req.Context(), model.UserID(userIdStr))
	}
	return nil, errors.NewUnauthenticated()
}

func (m *authMiddleware) authenticateOAuth(req *http.Request) (*model.User, errors.Err) {
	authHeader := req.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, oauthHeaderPrefix) {
		return nil, nil // not OAuth
	}
	token := authHeader[len(oauthHeaderPrefix):]
	user, err := m.service.authService.GetOrCreateOAuthUserForToken(req.Context(), token)
	if err != nil {
		return nil, err // OAuth error
	}
	return user, nil
}
