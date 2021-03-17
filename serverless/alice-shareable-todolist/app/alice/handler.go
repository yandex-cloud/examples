package alice

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
)

type Handler interface {
	Handle(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, error)
}
