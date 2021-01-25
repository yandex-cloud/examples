package main

import (
	"context"
	"strings"
	"time"

	"github.com/yandex-cloud/examples/serverless/serverless_voximplant/scheme"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func newSlots(ctx context.Context, req *slotsRequest) ([]*scheme.Entry, error) {
	query, params, err := newSlotsQuery(req)
	if err != nil {
		return nil, err
	}

	var entries []*scheme.Entry
	err = table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithSerializableReadWrite()), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		entries = make([]*scheme.Entry, 0, res.RowCount())
		for res.NextSet() {
			for res.NextRow() {
				entries = append(entries, new(scheme.Entry).FromYDB(res))
			}
		}
		return nil
	}))
	// optional: cancel old slots
	_ = cancelSlots(ctx, req.ClientID, req.CancelSlots)
	if err != nil {
		return nil, err
	}

	return entries, nil
}

func newSlotsQuery(req *slotsRequest) (query string, params *table.QueryParameters, err error) {
	switch {
	case len(req.ClientID) == 0:
		return "", nil, newErrorBadRequest("bad request: require `clientId`")
	case len(req.Spec) == 0:
		return "", nil, newErrorBadRequest("bad request: require `specId`")
	case len(req.Date) == 0:
		return "", nil, newErrorBadRequest("bad request: require `date`")
	}

	date, err := time.Parse(dateLayout, req.Date)
	if err != nil {
		return "", nil, err
	}

	params = table.NewQueryParameters()
	builder := new(strings.Builder)
	builder.WriteString("DECLARE $client_id AS Utf8;\n")
	params.Add(table.ValueParam("$client_id", ydb.UTF8Value(req.ClientID)))
	builder.WriteString("DECLARE $spec_id AS Utf8;\n")
	params.Add(table.ValueParam("$spec_id", ydb.UTF8Value(req.Spec)))
	builder.WriteString("DECLARE $date AS Date;\n")
	params.Add(table.ValueParam("$date", ydb.DateValue(ydb.Time(date).Date())))
	builder.WriteString("DECLARE $curr AS Datetime;\n")
	params.Add(table.ValueParam("$curr", ydb.DatetimeValue(ydb.Time(time.Now()).Datetime())))
	builder.WriteString("DECLARE $till AS Datetime;\n")
	params.Add(table.ValueParam("$till", ydb.DatetimeValue(ydb.Time(time.Now().Add(2*time.Minute)).Datetime())))
	var place ydb.Value
	if len(req.Place) > 0 {
		place = ydb.UTF8Value(req.Place)
		builder.WriteString("DECLARE $place_id AS Utf8;\n")
		params.Add(table.ValueParam("$place_id", place))
	}
	var doctors ydb.Value
	if len(req.Doctors) > 0 {
		var docs []ydb.Value
		for _, d := range req.Doctors {
			docs = append(docs, ydb.UTF8Value(d))
		}
		doctors = ydb.ListValue(docs...)
		builder.WriteString("DECLARE $doctors AS List<Utf8>;\n")
		params.Add(table.ValueParam("$doctors", doctors))
	}
	var excluded ydb.Value
	if len(req.ExcludeSlots) > 0 {
		var excl []ydb.Value
		for _, e := range req.ExcludeSlots {
			excl = append(excl, ydb.UTF8Value(e))
		}
		excluded = ydb.ListValue(excl...)
		builder.WriteString("DECLARE $excluded AS List<Utf8>;\n")
		params.Add(table.ValueParam("$excluded", excluded))
	}
	// select:
	builder.WriteString(`$to_update = (SELECT id, spec_id, doctor_id, place_id, ` +
		"`date`" + `, at, $client_id as patient, $till AS booked_till FROM schedule VIEW booked
WHERE
    spec_id = $spec_id AND ` + "`date`" + ` = $date`)
	if place != nil {
		builder.WriteString(` AND place_id = $place_id`)
	}
	if doctors != nil {
		builder.WriteString(` AND doctor_id IN $doctors`)
	}
	if excluded != nil {
		builder.WriteString(`
    AND id NOT IN $excluded`)
	}
	builder.WriteString(`
    AND (patient IS NULL OR patient = "" OR booked_till IS NULL OR booked_till < $curr)
ORDER BY at
LIMIT 2);

SELECT * FROM $to_update;

UPDATE schedule ON SELECT * FROM $to_update;
`)
	return builder.String(), params, nil
}

func cancelSlots(ctx context.Context, clientID string, slots []string) (err error) {
	switch {
	case len(slots) == 0:
		return nil
	case len(clientID) == 0:
		return newErrorBadRequest("bad request: require `clientId`")
	}

	params := table.NewQueryParameters()
	var canceled []ydb.Value
	for _, c := range slots {
		canceled = append(canceled, ydb.UTF8Value(c))
	}
	params.Add(table.ValueParam("$canceled", ydb.ListValue(canceled...)))
	params.Add(table.ValueParam("$client_id", ydb.UTF8Value(clientID)))
	query := `DECLARE $client_id AS Utf8;
DECLARE $canceled AS List<Utf8>;

UPDATE schedule
SET patient = NULL, booked_till = NULL
WHERE id IN $canceled AND patient = $client_id;`
	return table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithSerializableReadWrite()), table.CommitTx())
		_, _, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		return err
	}))
}

func ackSlot(ctx context.Context, req *ackSlotRequest) (*info, error) {
	query, params, err := ackSlotsQuery(req)
	if err != nil {
		return nil, err
	}

	var entry *scheme.Entry
	err = table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithSerializableReadWrite()), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params, table.WithQueryCachePolicy(table.WithQueryCachePolicyKeepInCache()))
		if err != nil {
			return err
		}

		defer res.Close()
		if res.RowCount() != 1 {
			// something went wrong, need to report. otherwise it's exactly the slot we asked for
			return newErrorBadRequest("failed to ack slot")
		}
		res.NextSet()
		res.NextRow()
		entry = new(scheme.Entry).FromYDB(res)
		return nil
	}))
	// optional: cancel old slots
	_ = cancelSlots(ctx, req.ClientID, req.CancelSlots)
	if err != nil {
		return nil, err
	}

	return slotInfo(ctx, entry)
}

func ackSlotsQuery(req *ackSlotRequest) (query string, params *table.QueryParameters, err error) {
	switch {
	case len(req.SlotID) == 0:
		return "", nil, newErrorBadRequest("bad request: require `slotId`")
	case len(req.ClientID) == 0:
		return "", nil, newErrorBadRequest("bad request: require `clientId`")
	}

	query = `DECLARE $slot_id AS Utf8;
DECLARE $client_id AS Utf8;

$slot = (SELECT id, spec_id, doctor_id, place_id, ` +
		"`date`" + `, at, patient, at AS booked_till FROM schedule
WHERE id = $slot_id AND patient = $client_id
LIMIT 1);

SELECT * FROM $slot;

UPDATE schedule ON SELECT * FROM $slot;
`
	params = table.NewQueryParameters()
	params.Add(table.ValueParam("$client_id", ydb.UTF8Value(req.ClientID)))
	params.Add(table.ValueParam("$slot_id", ydb.UTF8Value(req.SlotID)))
	return query, params, nil
}

type info struct {
	At     time.Time `json:"at"`
	Place  string    `json:"place"`
	Spec   string    `json:"spec"`
	Doctor string    `json:"doctor"`
}

func slotInfo(ctx context.Context, entry *scheme.Entry) (*info, error) {
	if entry == nil {
		return nil, newErrorBadRequest("nil slot")
	}
	doc, err := getDoc(ctx, entry.DoctorID)
	if err != nil {
		return nil, err
	}
	place, err := getPlace(ctx, entry.PlaceID)
	if err != nil {
		return nil, err
	}
	spec, err := getSpec(ctx, entry.SpecID)
	if err != nil {
		return nil, err
	}
	return &info{
		At:     entry.At,
		Place:  place.Name,
		Spec:   spec.Name,
		Doctor: doc.Name,
	}, nil
}
