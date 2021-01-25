package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"
	"time"

	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/auth/iam"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

var (
	driver      ydb.Driver
	tableClient *table.Client
	sessPool    *table.SessionPool
	db          string
	ep          string
)

const (
	EnvDB = "DATABASE"
	EnvEP = "ENDPOINT"
)

func init() {
	var ok bool
	db, ok = os.LookupEnv(EnvDB)
	if !ok {
		fmt.Fprintf(os.Stderr, "no DATABASE env var\n")
		os.Exit(-1)
	}
	ep, ok = os.LookupEnv(EnvEP)
	if !ok {
		fmt.Fprintf(os.Stderr, "no ENDPOINT env var\n")
		os.Exit(-1)
	}

	ca, err := x509.SystemCertPool()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read sys cert pool: %#v\n", err)
		os.Exit(-2)
	}
	driver, err = (&ydb.Dialer{
		DriverConfig: &ydb.DriverConfig{
			Database:          db,
			Credentials:       iam.InstanceServiceAccount(context.Background()),
			RequestTimeout:    15 * time.Second,
			OperationTimeout:  15 * time.Second,
			DiscoveryInterval: time.Minute,
			BalancingMethod:   ydb.BalancingP2C,
			BalancingConfig: &ydb.P2CConfig{
				PreferLocal:     true,
				OpTimeThreshold: time.Second,
			},
		},
		TLSConfig: &tls.Config{
			RootCAs: ca,
		},
		Timeout: 15 * time.Second,
	}).Dial(context.Background(), ep)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to conn to db: %#v\n", err)
		os.Exit(-3)
	}
	tableClient = &table.Client{Driver: driver}
	sessPool = &table.SessionPool{Builder: tableClient}
}
