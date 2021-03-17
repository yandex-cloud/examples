package cloud

import (
	"context"
)

type Deps interface {
	GetContext() context.Context
}
