package web

import (
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	webauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web/auth"
	"go.uber.org/zap"
)

type Deps interface {
	GetLogger() *zap.Logger
	GetWebAuthService() webauth.Service
	GetTODOListService() todolist.Service
}
