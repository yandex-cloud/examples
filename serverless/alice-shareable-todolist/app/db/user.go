package db

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func (r *repository) SaveUser(ctx context.Context, user *model.User) error {
	const query = `
DECLARE $id AS string;
DECLARE $name AS utf8;
DECLARE $avatar_id AS string;
UPSERT INTO user(id, name, yandex_avatar_id) VALUES ($id, $name, $avatar_id);
`
	return r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, _, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$id", ydb.StringValue([]byte(user.ID))),
			table.ValueParam("$name", ydb.UTF8Value(user.Name)),
			table.ValueParam("$avatar_id", ydb.StringValue([]byte(user.YandexAvatarID))),
		))
		return tx, err
	})
}

func (r *repository) GetUser(ctx context.Context, id model.UserID) (*model.User, error) {
	const query = `
DECLARE $id AS string;
SELECT id, name, yandex_avatar_id FROM user WHERE id = $id;
`
	var user *model.User
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
		user = &model.User{}
		return tx, readUser(res, user)
	})
	return user, err
}

func readUser(res *table.Result, u *model.User) error {
	er := entityReader("user")

	if id, err := er.fieldString(res, "id"); err != nil {
		return err
	} else {
		u.ID = model.UserID(id)
	}
	if name, err := er.fieldUtf8(res, "name"); err != nil {
		return err
	} else {
		u.Name = name
	}
	if avatar, err := er.fieldString(res, "yandex_avatar_id"); err != nil {
		return err
	} else {
		u.YandexAvatarID = string(avatar)
	}
	return nil
}
