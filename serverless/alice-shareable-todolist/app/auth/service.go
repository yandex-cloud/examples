package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/secure"
)

type Service interface {
	GetOAuthURL(ctx context.Context, opts ...OAuthOpt) *url.URL
	GetOrCreateOAuthUserForCode(ctx context.Context, code string) (*model.User, errors.Err)
	GetOrCreateOAuthUserForToken(ctx context.Context, code string) (*model.User, errors.Err)
	GetPreAuthenticatedUser(ctx context.Context, id model.UserID) (*model.User, errors.Err)
}

type Deps interface {
	GetConfig() *config.Config
	GetSecureConfig() *secure.Config
	GetRepository() db.Repository
	GetTxManager() db.TxManager
}

var _ Service = &service{}

type service struct {
	oauthClientID string
	oauthSecret   string
	domain        string
	repo          db.Repository
	txMgr         db.TxManager
	httpClient    http.Client
}

func NewService(deps Deps) (Service, error) {
	conf := deps.GetConfig()
	secConf := deps.GetSecureConfig()
	return &service{
		oauthClientID: conf.OAuthClientID,
		oauthSecret:   secConf.OAuthSecret,
		domain:        conf.Domain,
		repo:          deps.GetRepository(),
		txMgr:         deps.GetTxManager(),
	}, nil
}

func (s *service) GetPreAuthenticatedUser(ctx context.Context, id model.UserID) (*model.User, errors.Err) {
	var user *model.User
	err := s.txMgr.InTx(ctx, db.TxRO()).Do(func(ctx context.Context) error {
		var err error
		user, err = s.repo.GetUser(ctx, id)
		return err
	})
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.NewUnauthenticated()
	}
	return user, nil
}

func (s *service) GetOAuthURL(ctx context.Context, opts ...OAuthOpt) *url.URL {
	var options oauthOpts
	for _, opt := range opts {
		opt(&options)
	}
	res, _ := url.Parse("https://oauth.yandex.ru/authorize")
	q := make(url.Values)
	q.Add("response_type", "code")
	q.Add("client_id", s.oauthClientID)
	if options.redirectURI != nil {
		options.redirectURI.Scheme = "https"
		options.redirectURI.Host = s.domain
		q.Add("redirect_uri", options.redirectURI.String())
	}
	if options.force {
		q.Add("force_confirm", "yes")
	}
	if options.state != "" {
		q.Add("state", options.state)
	}
	res.RawQuery = q.Encode()
	return res
}

func (s *service) GetOrCreateOAuthUserForToken(ctx context.Context, token string) (*model.User, errors.Err) {
	user, err := s.getYandexUser(ctx, token)
	if err != nil {
		return nil, err
	}
	err = s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		return s.repo.SaveUser(ctx, user)
	})
	if err != nil {
		return nil, err
	}
	return user, nil
}
func (s *service) GetOrCreateOAuthUserForCode(ctx context.Context, code string) (*model.User, errors.Err) {
	token, err := s.getOAuthToken(ctx, code)
	if err != nil {
		return nil, err
	}
	return s.GetOrCreateOAuthUserForToken(ctx, token)
}

func (s *service) getYandexUser(ctx context.Context, oauthToken string) (*model.User, errors.Err) {
	req, err := http.NewRequest(http.MethodGet, "https://login.yandex.ru/info?format=json", nil)
	if err != nil {
		return nil, errors.NewInternal(err)
	}
	req = req.WithContext(ctx)
	req.Header.Add("Authorization", fmt.Sprintf("OAuth %s", oauthToken))
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, errors.NewInternal(err) //TODO
	}
	if resp.StatusCode != 200 {
		return nil, errors.NewInternal(fmt.Errorf("passport bad status: %d", resp.StatusCode)) //TODO
	}
	type yaPassportResponse struct {
		Login  string `json:"login"`
		Avatar string `json:"default_avatar_id"`
	}
	var jsonResp yaPassportResponse
	err = json.NewDecoder(resp.Body).Decode(&jsonResp)
	if err != nil {
		return nil, errors.NewInternal(fmt.Errorf("parsing passport response: %w", err))
	}
	if len(jsonResp.Login) == 0 {
		return nil, errors.NewInternal(fmt.Errorf("login not found in passport response"))
	}
	return &model.User{
		ID:             model.UserID(jsonResp.Login),
		Name:           jsonResp.Login,
		YandexAvatarID: jsonResp.Avatar,
	}, nil
}

func (s *service) getOAuthToken(ctx context.Context, code string) (string, errors.Err) {
	q := make(url.Values)
	q.Add("grant_type", "authorization_code")
	q.Add("code", code)
	q.Add("client_id", s.oauthClientID)
	q.Add("client_secret", s.oauthSecret)

	resp, err := s.httpClient.PostForm("https://oauth.yandex.ru/token", q)
	if err != nil {
		return "", errors.NewInternal(err) // TODO
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", errors.NewInternal(fmt.Errorf("oauth status: %d", resp.StatusCode)) // TODO
	}
	type oauthResp struct {
		AccessToken string `json:"access_token"`
	}
	var respJson oauthResp
	err = json.NewDecoder(resp.Body).Decode(&respJson)
	if err != nil {
		return "", errors.NewInternal(fmt.Errorf("parsing oauth response: %w", err))
	}
	return respJson.AccessToken, nil
}

type oauthOpts struct {
	force       bool
	redirectURI *url.URL
	state       string
}

type OAuthOpt func(*oauthOpts)

func OAuthForce(force bool) OAuthOpt {
	return func(opts *oauthOpts) {
		opts.force = force
	}
}

func OAuthRetPath(url *url.URL) OAuthOpt {
	return func(opts *oauthOpts) {
		opts.redirectURI = url
	}
}

func OAuthState(state string) OAuthOpt {
	return func(opts *oauthOpts) {
		opts.state = state
	}
}
