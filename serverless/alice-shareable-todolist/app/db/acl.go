package db

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func (r *repository) DeleteACL(ctx context.Context, userID model.UserID, listID model.TODOListID) error {
	const query = `
DECLARE $user_id AS string;
DECLARE $list_id AS string;
DELETE FROM todolist_acl WHERE list_id = $list_id AND user_id = $user_id;
`
	return r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, _, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$user_id", ydb.StringValue([]byte(userID))),
			table.ValueParam("$list_id", ydb.StringValue([]byte(listID))),
		))
		return tx, err
	})
}

func (r *repository) SaveACLEntry(ctx context.Context, entry *model.ACLEntry) error {
	const query = `
DECLARE $user_id AS string;
DECLARE $mode AS string;
DECLARE $list_id AS string;
DECLARE $alias AS utf8;
DECLARE $inviter AS string;
DECLARE $accepted AS bool;
UPSERT INTO todolist_acl(user_id, mode, list_id, alias, inviter, accepted) VALUES ($user_id, $mode, $list_id, $alias, $inviter, $accepted);
`
	return r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, _, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$user_id", ydb.StringValue([]byte(entry.User))),
			table.ValueParam("$inviter", ydb.StringValue([]byte(entry.Inviter))),
			table.ValueParam("$mode", ydb.StringValue([]byte(entry.Mode))),
			table.ValueParam("$list_id", ydb.StringValue([]byte(entry.ListID))),
			table.ValueParam("$alias", ydb.UTF8Value(string(entry.Alias))),
			table.ValueParam("$accepted", ydb.BoolValue(entry.Accepted)),
		))
		return tx, err
	})
}

func (r *repository) ListACLByUser(ctx context.Context, id model.UserID) ([]*model.ACLEntry, error) {
	const query = `
DECLARE $user_id AS string;
SELECT user_id, mode, list_id, alias, inviter, accepted FROM todolist_acl WHERE user_id = $user_id;
`
	var acl []*model.ACLEntry
	err := r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, res, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$user_id", ydb.StringValue([]byte(id))),
		))
		if err != nil {
			return nil, err
		}
		defer res.Close()
		acl, err = readACL(res)
		return tx, err
	})
	if err != nil {
		return nil, err
	}
	return acl, nil
}

func (r *repository) ListACLByList(ctx context.Context, id model.TODOListID) ([]*model.ACLEntry, error) {
	const query = `
DECLARE $list_id AS string;
SELECT user_id, mode, list_id, alias, inviter, accepted FROM todolist_acl WHERE list_id = $list_id;
`
	var acl []*model.ACLEntry
	err := r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, res, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$list_id", ydb.StringValue([]byte(id))),
		))
		if err != nil {
			return nil, err
		}
		defer res.Close()
		acl, err = readACL(res)
		return tx, err
	})
	if err != nil {
		return nil, err
	}
	return acl, nil
}

func (r *repository) GetACL(ctx context.Context, userID model.UserID, listID model.TODOListID) (*model.ACLEntry, error) {
	const query = `
DECLARE $user_id AS string;
DECLARE $list_id AS string;
SELECT user_id, mode, list_id, alias, inviter, accepted FROM todolist_acl WHERE list_id = $list_id AND user_id = $user_id;
`
	var acl *model.ACLEntry
	err := r.execute(ctx, func(ctx context.Context, s *table.Session, txc *table.TransactionControl) (*table.Transaction, error) {
		tx, res, err := s.Execute(ctx, txc, query, table.NewQueryParameters(
			table.ValueParam("$user_id", ydb.StringValue([]byte(userID))),
			table.ValueParam("$list_id", ydb.StringValue([]byte(listID))),
		))
		if err != nil {
			return nil, err
		}
		defer res.Close()
		if !res.NextSet() || !res.NextRow() {
			return tx, nil
		}
		acl = &model.ACLEntry{}
		err = readACLEntry(res, acl)
		return tx, err
	})
	if err != nil {
		return nil, err
	}
	return acl, nil
}

func readACL(r *table.Result) ([]*model.ACLEntry, error) {
	var acl []*model.ACLEntry
	for r.NextSet() {
		for r.NextRow() {
			var e model.ACLEntry
			if err := readACLEntry(r, &e); err != nil {
				return nil, err
			}
			acl = append(acl, &e)
		}
	}
	return acl, nil
}

func readACLEntry(r *table.Result, acl *model.ACLEntry) error {
	er := entityReader("todolist_acl")

	if user, err := er.fieldString(r, "user_id"); err != nil {
		return err
	} else {
		acl.User = model.UserID(user)
	}
	if mode, err := er.fieldString(r, "mode"); err != nil {
		return err
	} else {
		acl.Mode = model.AccessMode(mode)
	}
	if list, err := er.fieldString(r, "list_id"); err != nil {
		return err
	} else {
		acl.ListID = model.TODOListID(list)
	}
	if alias, err := er.fieldUtf8(r, "alias"); err != nil {
		return err
	} else {
		acl.Alias = alias
	}
	if accepted, err := er.fieldBool(r, "accepted"); err != nil {
		return err
	} else {
		acl.Accepted = accepted
	}
	if inviter, err := er.fieldString(r, "inviter"); err != nil {
		return err
	} else {
		acl.Inviter = model.UserID(inviter)
	}
	return nil
}
