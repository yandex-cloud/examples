package main

import (
	"context"
	"time"

	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

const dateLayout = "2006-01-02"

func listDates(ctx context.Context, req *datesRequest) ([]string, error) {
	if len(req.Spec) == 0 {
		return nil, newErrorBadRequest("bad request: require `specId`")
	}

	var query string
	params := table.NewQueryParameters()

	if len(req.Place) > 0 {
		query = `DECLARE $place_id AS Utf8;
DECLARE $spec_id AS Utf8;
SELECT DISTINCT` + "`date`" + `FROM schedule
WHERE spec_id = $spec_id AND place_id = $place_id
ORDER BY ` + "`date`" + `
LIMIT 10`
		params.Add(table.ValueParam("$spec_id", ydb.UTF8Value(req.Spec)))
		params.Add(table.ValueParam("$place_id", ydb.UTF8Value(req.Place)))
	} else {
		query = `DECLARE $spec_id AS Utf8;
SELECT DISTINCT` + "`date`" + `FROM schedule
WHERE spec_id = $spec_id
ORDER BY ` + "`date`" + `
LIMIT 10`
		params.Add(table.ValueParam("$spec_id", ydb.UTF8Value(req.Spec)))
	}

	var dates []string

	err := table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		dates = make([]string, 0, res.RowCount())
		for res.NextSet() {
			for res.NextRow() {
				if res.SeekItem("date") {
					d := res.ODate()
					if d > 0 {
						t := new(ydb.Time)
						err := t.FromDate(d)
						if err != nil {
							continue
						}
						dates = append(dates, time.Time(*t).Format(dateLayout))
					}
				}
			}
		}
		return nil
	}))
	if err != nil {
		return nil, err
	}

	return dates, nil
}
