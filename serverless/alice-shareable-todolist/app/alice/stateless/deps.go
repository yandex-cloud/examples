package stateless

import (
	aliceauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	"go.uber.org/zap"
)

type Deps interface {
	GetTODOListService() todolist.Service
	GetAliceAuthService() aliceauth.Service
	GetLogger() *zap.Logger
}
