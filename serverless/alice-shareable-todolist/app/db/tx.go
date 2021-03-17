package db

import (
	"context"
	"fmt"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/ydb-go-sdk/table"
	"go.uber.org/zap"
)

type TxManager interface {
	InTx(ctx context.Context, opts ...TxOpt) *TxRunner
}

func NewTxManager(deps Deps) (TxManager, error) {
	sp, err := initSessionPool(deps.GetContext(), deps.GetConfig())
	if err != nil {
		return nil, err
	}
	return &txManagerImpl{sp: sp}, nil
}

var _ TxManager = &txManagerImpl{}

type txManagerImpl struct {
	sp *table.SessionPool
}

func (t *txManagerImpl) InTx(ctx context.Context, opts ...TxOpt) *TxRunner {
	conf := txOpts{}
	for _, opt := range opts {
		opt(&conf)
	}
	return &TxRunner{
		ctx:  ctx,
		opts: &conf,
		sp:   t.sp,
	}
}

type txOpts struct {
	ro bool
}
type TxOpt func(o *txOpts)

func TxRO() TxOpt {
	return func(o *txOpts) {
		o.ro = true
	}
}

type TxRunner struct {
	ctx  context.Context
	opts *txOpts
	sp   *table.SessionPool
}

func (r *TxRunner) Do(action func(ctx context.Context) error) errors.Err {
	err := table.Retry(r.ctx, r.sp, table.OperationFunc(
		func(ctx context.Context, session *table.Session) error {
			tx := &txCtx{
				readonly: r.opts.ro,
				session:  session,
			}
			ctx = ctxWithTx(ctx, tx)
			defer tx.close(ctx)
			err := action(ctx)
			if err == nil {
				err = tx.commit(ctx)
				if err != nil {
					return errors.NewInternal(err)
				}
				return nil
			}
			if appErr, ok := err.(errors.Err); ok {
				return appErr
			}
			return err
		},
	))
	if err != nil {
		return errors.NewInternal(err)
	}
	return nil
}

type txCtxKey struct{}

func ctxWithTx(ctx context.Context, tx *txCtx) context.Context {
	return context.WithValue(ctx, txCtxKey{}, tx)
}

func txFromCtx(ctx context.Context) *txCtx {
	res := ctx.Value(txCtxKey{})
	if res == nil {
		return nil
	}
	return res.(*txCtx)
}

type txCtx struct {
	readonly bool
	session  *table.Session
	tx       *table.Transaction
}

func (c *txCtx) commit(ctx context.Context) error {
	if c.readonly {
		return nil
	}
	if c.tx == nil {
		return nil
	}
	_, err := c.tx.CommitTx(ctx)
	c.tx = nil
	return err
}

func (c *txCtx) close(ctx context.Context) {
	if c.readonly {
		return
	}
	if c.tx != nil {
		err := c.tx.Rollback(ctx)
		if err != nil {
			log.Warn(ctx, "rollback failed", zap.Error(err))
		}
		c.tx = nil
	}
}

type queryFunc func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error)

func (r *repository) execute(ctx context.Context, action queryFunc) error {
	txCtx := txFromCtx(ctx)
	if txCtx == nil {
		return fmt.Errorf("transaction required")
	}
	var err error
	var txc *table.TransactionControl
	if txCtx.tx != nil {
		txc = table.TxControl(table.WithTx(txCtx.tx))
	} else if txCtx.readonly {
		txc = table.TxControl(table.BeginTx(table.WithOnlineReadOnly()), table.CommitTx())
	} else {
		txc = table.TxControl(table.BeginTx(table.WithSerializableReadWrite()))
	}
	tx, err := action(ctx, txCtx.session, txc)
	if err != nil {
		return err
	}
	if txCtx.tx == nil && !txCtx.readonly {
		txCtx.tx = tx
	}
	return nil
}
