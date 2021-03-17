package apigw

import (
	"io"
)

type readCloser struct {
	io.Reader
}

func (rc readCloser) Close() error { return nil }
