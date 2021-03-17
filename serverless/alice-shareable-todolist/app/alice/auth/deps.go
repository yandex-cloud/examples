package auth

import (
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
)

type Deps interface {
	GetAuthService() auth.Service
	GetRepository() db.Repository
}
