package main

import (
	"context"
	"fmt"
	"time"

	"github.com/yandex-cloud/examples/serverless/serverless_voximplant/scheme"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func listDocs(ctx context.Context, req *doctorsRequest) ([]*scheme.Doctor, error) {
	switch {
	case len(req.Spec) == 0:
		return nil, newErrorBadRequest("bad request: require `specId`")
	case len(req.Date) == 0:
		return nil, newErrorBadRequest("bad request: require `date`")
	}

	date, err := time.Parse(dateLayout, req.Date)
	if err != nil {
		return nil, err
	}

	var query string
	params := table.NewQueryParameters()

	if len(req.Place) > 0 {
		query = `DECLARE $place_id AS Utf8;
DECLARE $spec_id AS Utf8;
DECLARE $date AS Date;
SELECT DISTINCT doctor_id FROM schedule
WHERE spec_id = $spec_id AND ` + "`date`" + ` = $date AND place_id = $place_id
LIMIT 10`
		params.Add(table.ValueParam("$spec_id", ydb.UTF8Value(req.Spec)))
		params.Add(table.ValueParam("$date", ydb.DateValue(ydb.Time(date).Date())))
		params.Add(table.ValueParam("$place_id", ydb.UTF8Value(req.Place)))
	} else {
		query = `DECLARE $spec_id AS Utf8;
DECLARE $date AS Date;
SELECT DISTINCT doctor_id FROM schedule
WHERE spec_id = $spec_id AND ` + "`date`" + ` = $date
LIMIT 10`
		params.Add(table.ValueParam("$spec_id", ydb.UTF8Value(req.Spec)))
		params.Add(table.ValueParam("$date", ydb.DateValue(ydb.Time(date).Date())))
	}

	var docIDs []string
	err = table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		docIDs = make([]string, 0, res.RowCount())
		for res.NextSet() {
			for res.NextRow() {
				if res.SeekItem("doctor_id") {
					docIDs = append(docIDs, res.OUTF8())
				}
			}
		}
		return nil
	}))
	if err != nil {
		return nil, err
	}
	if len(docIDs) == 0 {
		return []*scheme.Doctor{}, nil
	}

	query = `DECLARE $ids AS List<Utf8>;
SELECT id, name FROM doctors
WHERE id IN $ids
ORDER BY name
LIMIT 10`
	var ids []ydb.Value
	for _, id := range docIDs {
		ids = append(ids, ydb.UTF8Value(id))
	}
	params = table.NewQueryParameters(table.ValueParam("$ids", ydb.ListValue(ids...)))
	var docs []*scheme.Doctor
	err = table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		docs = make([]*scheme.Doctor, 0, res.RowCount())
		for res.NextSet() {
			for res.NextRow() {
				docs = append(docs, new(scheme.Doctor).FromYDB(res))
			}
		}
		return nil
	}))
	if err != nil {
		return nil, err
	}

	return docs, nil
}

func getDoc(ctx context.Context, id string) (result *scheme.Doctor, err error) {
	query := `DECLARE $id as UTF8;
SELECT * FROM doctors
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
			return fmt.Errorf("no such doctor")
		}
		res.NextSet()
		res.NextRow()
		result = new(scheme.Doctor).FromYDB(res)
		return nil
	}))
	return result, err
}
