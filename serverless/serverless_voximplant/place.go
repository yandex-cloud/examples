package main

import (
	"context"
	"fmt"

	"github.com/yandex-cloud/examples/serverless/serverless_voximplant/scheme"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

// list available places
func listPlaces(ctx context.Context) ([]*scheme.Place, error) {
	var places []*scheme.Place
	query := "SELECT * FROM places"
	err := table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, nil, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		for res.NextSet() {
			for res.NextRow() {
				places = append(places, new(scheme.Place).FromYDB(res))
			}
		}
		return nil
	}))
	if err != nil {
		return nil, err
	}
	return places, nil
}

func getPlace(ctx context.Context, id string) (result *scheme.Place, err error) {
	query := `DECLARE $id as UTF8;
SELECT * FROM places
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
			return fmt.Errorf("no such place, rows: %d", res.RowCount())
		}
		res.NextSet()
		res.NextRow()
		result = new(scheme.Place).FromYDB(res)
		return nil
	}))
	return result, err
}
