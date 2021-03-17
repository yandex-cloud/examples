package todolist

import (
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
)

type Deps interface {
	GetRepository() db.Repository
	GetTxManager() db.TxManager
}
