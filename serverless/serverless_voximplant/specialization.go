package main

import (
	"context"
	"fmt"

	"github.com/yandex-cloud/examples/serverless/serverless_voximplant/scheme"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

// list available specs
func listSpecs(ctx context.Context) ([]*scheme.Specialization, error) {
	var specs []*scheme.Specialization
	query := "SELECT * FROM specializations"
	err := table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, nil, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}
		for res.NextSet() {
			for res.NextRow() {
				specs = append(specs, new(scheme.Specialization).FromYDB(res))
			}
		}
		return nil
	}))
	if err != nil {
		return nil, err
	}
	return specs, nil
}

func getSpec(ctx context.Context, id string) (result *scheme.Specialization, err error) {
	query := `DECLARE $id as UTF8;
SELECT * FROM specializations
WHERE id = $id
LIMIT 1;`
	params := table.NewQueryParameters(table.ValueParam("$id", ydb.UTF8Value(id)))
	err = table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		if res.RowCount() != 1 {
			return fmt.Errorf("no such specialization")
		}
		res.NextSet()
		res.NextRow()
		result = new(scheme.Specialization).FromYDB(res)
		return nil
	}))
	return result, err
}
