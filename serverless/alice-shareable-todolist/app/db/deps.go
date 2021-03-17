package db

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
)

type Deps interface {
	GetConfig() *config.Config
	GetContext() context.Context
}
