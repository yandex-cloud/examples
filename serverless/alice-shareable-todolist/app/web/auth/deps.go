package auth

import (
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/secure"
)

type Deps interface {
	GetConfig() *config.Config
	GetSecureConfig() *secure.Config
	GetAuthService() auth.Service
	GetRepository() db.Repository
}
