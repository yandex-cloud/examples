package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

var yaPassportClient *http.Client = &http.Client{}

func authenticateByToken(ctx context.Context, token string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, "https://login.yandex.ru/info?format=json", nil)
	if err != nil {
		return "", err
	}
	req = req.WithContext(ctx)
	req.Header.Add("Authorization", fmt.Sprintf("OAuth %s", token))
	resp, err := yaPassportClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case 200: //ok
	case 401:
		return "", newErrorUnauthorized("bad OAuth token")
	default:
		return "", fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}
	var jsonResp yaPassportResponse
	err = json.NewDecoder(resp.Body).Decode(&jsonResp)
	if err != nil {
		return "", err
	}
	if len(jsonResp.Login) == 0 {
		return "", fmt.Errorf("login not found in passport response")
	}
	return jsonResp.Login, nil
}

func authorizeUser(ctx context.Context, login string) error {
	params := table.NewQueryParameters()
	params.Add(table.ValueParam("$login", ydb.UTF8Value(login)))
	query := `DECLARE $login AS Utf8;
			  SELECT login FROM authorized_users WHERE login = $login LIMIT 1`
	authorized := false
	err := table.Retry(ctx, sessPool, table.OperationFunc(func(ctx context.Context, session *table.Session) error {
		txc := table.TxControl(table.BeginTx(table.WithOnlineReadOnly(table.WithInconsistentReads())), table.CommitTx())
		_, res, err := session.Execute(ctx, txc, query, params)
		if err != nil {
			return err
		}
		authorized = res.NextSet() && res.NextRow() && res.SeekItem("login") && res.OUTF8() == login
		return nil
	}))
	if err != nil {
		return err
	}
	if authorized {
		return nil
	}
	return newErrorUnauthorized("user not authorized")
}

type yaPassportResponse struct {
	Login string `json:"login"`
}
