package db

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"time"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/auth/iam"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func initSessionPool(ctx context.Context, conf *config.Config) (*table.SessionPool, error) {
	ca, err := x509.SystemCertPool()
	if err != nil {
		return nil, err
	}
	dialer := &ydb.Dialer{
		DriverConfig: &ydb.DriverConfig{
			Database:         conf.Database,
			Credentials:      iam.InstanceServiceAccount(ctx),
			RequestTimeout:   3 * time.Second,
			StreamTimeout:    3 * time.Second,
			OperationTimeout: 3 * time.Second,
		},
		TLSConfig: &tls.Config{RootCAs: ca},
		Timeout:   3 * time.Second,
	}
	driver, err := dialer.Dial(ctx, conf.DatabaseEndpoint)
	if err != nil {
		return nil, fmt.Errorf("dial error: %v", err)
	}

	tableClient := table.Client{Driver: driver}
	return &table.SessionPool{
		IdleThreshold: time.Second,
		Builder:       &tableClient,
	}, nil
}
