package secure

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/go-sdk"
)

type Deps interface {
	GetConfig() *config.Config
	GetCloudSDK() *ycsdk.SDK
	GetContext() context.Context
}
