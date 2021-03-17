package db

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func (r *repository) GetTODOList(ctx context.Context, id model.TODOListID) (*model.TODOList, error) {
	const query = `
DECLARE $id AS string;
SELECT id, owner_user_id, items FROM todolist WHERE id = $id;
`
	var list *model.TODOList
	err := r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, res, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$id", ydb.StringValue([]byte(id))),
		))
		if err != nil {
			return nil, err
		}
		defer res.Close()
		if !res.NextSet() || !res.NextRow() {
			return tx, nil
		}
		list = &model.TODOList{}
		return tx, readTODOList(res, list)
	})
	return list, err
}

func (r *repository) SaveTODOList(ctx context.Context, list *model.TODOList) error {
	const query = `
DECLARE $id AS string;
DECLARE $owner_user_id AS string;
DECLARE $items AS json;
UPSERT INTO todolist(id, owner_user_id, items) VALUES ($id, $owner_user_id, $items);
`
	itemsJson, err := json.Marshal(list.Items)
	if err != nil {
		return fmt.Errorf("serializing list items: %w", err)
	}
	return r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, _, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$id", ydb.StringValue([]byte(list.ID))),
			table.ValueParam("$owner_user_id", ydb.StringValue([]byte(list.Owner))),
			table.ValueParam("$items", ydb.JSONValue(string(itemsJson))),
		))
		return tx, err
	})
}

func (r *repository) DeleteTODOList(ctx context.Context, id model.TODOListID) error {
	const query = `
DECLARE $id AS string;
DELETE FROM todolist WHERE id = $id;
`
	return r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, _, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$id", ydb.StringValue([]byte(id))),
		))
		return tx, err
	})
}

func readTODOList(res *table.Result, l *model.TODOList) error {
	er := entityReader("todo_list")
	if id, err := er.fieldString(res, "id"); err != nil {
		return err
	} else {
		l.ID = model.TODOListID(id)
	}
	if owner, err := er.fieldString(res, "owner_user_id"); err != nil {
		return err
	} else {
		l.Owner = model.UserID(owner)
	}
	res.SeekItem("items")
	res.Unwrap()
	if res.Err() != nil {
		return res.Err()
	}
	return readTODOListItem(res, &l.Items)
}

func readTODOListItem(res *table.Result, item *[]*model.ListItem) error {
	itemJson := res.JSON()
	if res.Err() != nil {
		return fmt.Errorf("reading list item: %w", res.Err())
	}
	err := json.Unmarshal([]byte(itemJson), item)
	if err != nil {
		return fmt.Errorf("parsing list item: %w", err)
	}
	return nil
}
